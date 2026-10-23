provider "linode" {
  token = var.linode_token
}

# Fetch the caller's current public IPs (v4 and v6) when they opt in to
# allowlisting themselves through the control-plane ACL. Kept in
# `hashicorp/http` (an official provider) rather than a null_resource + curl.
# Both endpoints are queried; on a dual-stack runner both succeed, on
# single-stack the unreachable side will error the plan — split the flag if
# your runner is IPv4-only or IPv6-only.
data "http" "my_ipv4" {
  count = var.lke_acl_enabled && var.lke_acl_allow_my_ip ? 1 : 0
  url   = "https://ipv4.icanhazip.com"
  retry {
    attempts = 3
  }
}

data "http" "my_ipv6" {
  count = var.lke_acl_enabled && var.lke_acl_allow_my_ip ? 1 : 0
  url   = "https://ipv6.icanhazip.com"
  retry {
    attempts = 3
  }
}

module "lke" {
  source      = "./modules/kube"
  lke_config  = coalesce(var.kubeconfig_path, "${path.module}/kube.config")
  k8s_version = var.k8s_version

  control_plane_acl = var.lke_acl_enabled ? {
    enabled = true
    ipv4 = distinct(concat(
      var.lke_acl_ipv4,
      var.lke_acl_allow_my_ip ? ["${trimspace(data.http.my_ipv4[0].response_body)}/32"] : [],
    ))
    ipv6 = distinct(concat(
      var.lke_acl_ipv6,
      var.lke_acl_allow_my_ip ? ["${trimspace(data.http.my_ipv6[0].response_body)}/128"] : [],
    ))
  } : null
}

provider "kubernetes" {
  config_paths = [module.lke.lke_config]
}

provider "kubectl" {
  config_path      = module.lke.lke_config
  load_config_file = true
}

provider "helm" {
  kubernetes = {
    config_paths = [module.lke.lke_config]
  }
}

# Cloud Firewall on every node, kept attached by Linode's controller (see
# modules/cloud_firewall): NodePorts only from NodeBalancers.
module "cloud_firewall" {
  count  = var.cloud_firewall_enabled ? 1 : 0
  source = "./modules/cloud_firewall"
}

module "external_dns" {
  depends_on                = [module.lke]
  source                    = "./modules/external_dns"
  external_dns_token_expiry = var.external_dns_token_expiry
  # Once the Gateway owns the hostnames, stop reading Ingress/Service so the
  # two sources can't fight over the same records during/after cutover.
  sources = var.gateway_enabled ? ["gateway-httproute", "gateway-tcproute"] : ["service", "ingress"]
}

module "cert_manager" {
  # module.gateway installs the Gateway API CRDs; cert-manager's gateway-shim
  # refuses to start without them, so it must come after.
  depends_on          = [module.lke, module.gateway]
  source              = "./modules/cert_manager"
  issuer_email        = var.issuer_email
  linode_api_token    = module.external_dns.linode_api_token
  gateway_api_enabled = var.gateway_enabled
}


# Single Gateway API entrypoint (one NodeBalancer). See modules/gateway.
module "gateway" {
  count          = var.gateway_enabled ? 1 : 0
  depends_on     = [module.lke]
  source         = "./modules/gateway"
  ipv6_ingress   = var.gateway_ipv6_ingress
  example_host   = var.example_host
  proxy_protocol = var.gateway_proxy_protocol

  http_routes = concat(
    var.example_host != "" ? [{ hostname = var.example_host, namespace = "gateway", service = "example", port = 80 }] : [],
    (var.jhub_hostname != "" && var.jhub_client_id != "" && var.jhub_client_secret != "") ? [{ hostname = var.jhub_hostname, namespace = "jupyterhub", service = "proxy-public", port = 80 }] : [],
    local.triage_enabled ? [{ hostname = var.triage_host, namespace = var.triage_namespace, service = "triage-party", port = 8080 }] : [],
    var.extra_http_routes,
  )

  tcp_routes = (var.mc_router_enabled && length(var.minecraft) > 0) ? [{
    hostnames = [for m in var.minecraft : m.hostname]
    namespace = "mc-router"
    service   = "mc-router"
    port      = 25565
    # mc-router must accept the header before Envoy starts sending it.
    proxy_protocol = var.mc_router_proxy_protocol == "on"
  }] : []
}

check "proxy_protocol_needs_node_firewall" {
  assert {
    condition     = var.gateway_proxy_protocol != "on" || var.cloud_firewall_enabled
    error_message = "gateway_proxy_protocol = \"on\" without cloud_firewall_enabled: NodePorts are reachable from the internet, so client IPs can be forged with a PROXY header."
  }
}

check "mc_router_proxy_protocol_needs_node_firewall" {
  assert {
    condition     = var.gateway_enabled || var.mc_router_proxy_protocol != "on" || var.cloud_firewall_enabled
    error_message = "mc_router_proxy_protocol = \"on\" on mc-router's own NodeBalancer without cloud_firewall_enabled: its NodePort is reachable from the internet, so client IPs can be forged with a PROXY header."
  }
}

module "longhorn" {
  count      = var.longhorn_enabled ? 1 : 0
  depends_on = [module.lke]
  source     = "./modules/longhorn"
}

module "cosi" {
  count              = var.cosi_enabled ? 1 : 0
  depends_on         = [module.lke]
  source             = "./modules/cosi"
  token_expiry       = coalesce(var.cosi_token_expiry, var.external_dns_token_expiry)
  image_pull_secrets = local.dockerhub_enabled ? ["dockerhub"] : []
}

module "minecraft" {
  count        = length(var.minecraft)
  depends_on   = [module.lke, module.longhorn]
  source       = "./modules/minecraft"
  namespace    = var.minecraft[count.index].namespace
  ops          = var.minecraft[count.index].ops
  hostname     = var.minecraft[count.index].hostname
  motd         = var.minecraft[count.index].motd
  claim        = var.minecraft[count.index].claim
  mc_version   = try(var.minecraft[count.index].mc_version, "LATEST")
  service_type = var.mc_router_enabled ? "ClusterIP" : try(var.minecraft[count.index].service_type, "LoadBalancer")
  # Scale to zero: mc-router routes from Service annotations and scales the
  # servers that opted in. See modules/mc_router/README.md.
  mc_router_discovery = local.mc_router_autoscale
  scale_to_zero       = local.mc_router_autoscale && var.minecraft[count.index].scale_to_zero
}

module "mc_router" {
  count          = var.mc_router_enabled && length(var.minecraft) > 0 ? 1 : 0
  depends_on     = [module.lke, module.minecraft]
  source         = "./modules/mc_router"
  service_type   = var.gateway_enabled ? "ClusterIP" : "LoadBalancer"
  proxy_protocol = var.mc_router_proxy_protocol
  # A name only (no dependency): the Secret is created after the release,
  # in the namespace the release creates.
  image_pull_secrets = local.dockerhub_enabled ? ["dockerhub"] : []
  autoscale = {
    enabled    = local.mc_router_autoscale
    namespaces = [for m in var.minecraft : m.namespace if m.scale_to_zero]
  }
  mappings = [
    for m in var.minecraft : {
      hostname = m.hostname
      target   = "minecraft.${m.namespace}.svc.cluster.local:${m.port}"
    }
  ]
}

check "scale_to_zero_needs_mc_router_autoscale" {
  assert {
    condition     = local.mc_router_autoscale || alltrue([for m in var.minecraft : !m.scale_to_zero])
    error_message = "A minecraft entry sets scale_to_zero, but mc_router_enabled and mc_router_autoscale aren't both true: nothing would wake it, so it stays a Deployment."
  }
}

module "triage" {
  count          = local.triage_enabled ? 1 : 0
  depends_on     = [module.lke]
  source         = "./modules/triage"
  gh_token       = var.gh_token
  triage_host    = var.triage_host
  namespace      = var.triage_namespace
  name           = var.triage_name
  repos          = var.triage_repos
  create_ingress = !var.gateway_enabled
}

check "triage_needs_repos" {
  assert {
    condition     = var.triage_host == "" || length(var.triage_repos) > 0
    error_message = "triage_host is set but triage_repos is empty. Pass the GitHub repositories Triage Party should read (https://github.com/org/repo)."
  }
}

module "jhub" {
  count          = (var.jhub_hostname != "" && var.jhub_client_id != "" && var.jhub_client_secret != "") ? 1 : 0
  depends_on     = [module.lke]
  source         = "./modules/jhub"
  hostname       = var.jhub_hostname
  client_id      = var.jhub_client_id
  client_secret  = var.jhub_client_secret
  gh_admin_users = var.gh_admin_users
  hub_db_volume  = var.jhub_db_volume
  create_ingress = !var.gateway_enabled
}

locals {
  triage_enabled    = var.gh_token != "" && var.triage_host != "" && length(var.triage_repos) > 0
  dockerhub_enabled = var.dockerhub_username != "" && var.dockerhub_token != ""
  # Namespaces with pods pulling from Docker Hub under the `default`
  # ServiceAccount; the itzg minecraft and triage images run `:latest`/Always.
  dockerhub_default_sa_namespaces = concat(
    [for m in var.minecraft : m.namespace],
    local.triage_enabled ? [var.triage_namespace] : [],
    var.gateway_enabled && var.example_host != "" ? ["gateway"] : [],
  )
  cosi_namespaces      = var.cosi_enabled ? ["linode-cosi-driver"] : []
  mc_router_namespaces = var.mc_router_enabled && length(var.minecraft) > 0 ? ["mc-router"] : []
  mc_router_autoscale  = var.mc_router_enabled && length(var.minecraft) > 0 && var.mc_router_autoscale
  # Runner pods use the chart's own ServiceAccount; the Secret reaches them
  # through the scale set's pod template (image_pull_secrets).
  github_runners_enabled    = length(var.github_runner_scale_sets) > 0
  github_runners_namespaces = local.github_runners_enabled ? ["arc-runners"] : []
}

# Self-hosted GitHub Actions runners (modules/github_runners), scaled on demand.
module "github_runners" {
  count              = local.github_runners_enabled ? 1 : 0
  depends_on         = [module.lke]
  source             = "./modules/github_runners"
  scale_sets         = var.github_runner_scale_sets
  github_token       = var.github_runner_token
  github_app         = var.github_runner_app
  image_pull_secrets = local.dockerhub_enabled ? ["dockerhub"] : []
  image_cache        = var.github_runner_image_cache
  toolchain_cache    = var.github_runner_toolchain_cache
  image_cache_upstream_credentials = local.dockerhub_enabled ? {
    username = var.dockerhub_username
    password = var.dockerhub_token
  } : null
}

module "registry_auth" {
  count      = local.dockerhub_enabled ? 1 : 0
  depends_on = [module.cosi, module.minecraft, module.mc_router, module.triage, module.gateway, module.github_runners]
  source     = "./modules/registry_auth"
  username   = var.dockerhub_username
  token      = var.dockerhub_token
  namespaces = concat(local.dockerhub_default_sa_namespaces, local.cosi_namespaces, local.mc_router_namespaces, local.github_runners_namespaces)
  # mc-router runs under its chart's own ServiceAccount; it gets the Secret
  # through the chart's imagePullSecrets value instead.
  default_service_account_namespaces = local.dockerhub_default_sa_namespaces
}

# Fail the plan once the Docker Hub token has expired, rather than letting
# pulls quietly fall back to anonymous (and rate-limited) access.
resource "terraform_data" "dockerhub_token_expiry" {
  count = local.dockerhub_enabled && var.dockerhub_token_expiry != "" ? 1 : 0
  input = var.dockerhub_token_expiry
  lifecycle {
    precondition {
      condition     = timecmp(plantimestamp(), var.dockerhub_token_expiry) < 0
      error_message = "dockerhub_token expired at ${var.dockerhub_token_expiry}. Create a new Docker Hub access token and update dockerhub_token and dockerhub_token_expiry in terraform.tfvars."
    }
  }
}

check "dockerhub_token_expiry_soon" {
  assert {
    condition     = !local.dockerhub_enabled || var.dockerhub_token_expiry == "" || timecmp(timeadd(plantimestamp(), "720h"), var.dockerhub_token_expiry) < 0
    error_message = "dockerhub_token expires within 30 days (${var.dockerhub_token_expiry}). Rotate it soon."
  }
}
