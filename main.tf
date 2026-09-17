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
  lke_config  = "${path.module}/kube.config"
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
  count        = var.gateway_enabled ? 1 : 0
  depends_on   = [module.lke]
  source       = "./modules/gateway"
  ipv6_ingress = var.gateway_ipv6_ingress
  example_host = var.example_host

  http_routes = concat(
    var.example_host != "" ? [{ hostname = var.example_host, namespace = "gateway", service = "example", port = 80 }] : [],
    (var.jhub_hostname != "" && var.jhub_client_id != "" && var.jhub_client_secret != "") ? [{ hostname = var.jhub_hostname, namespace = "jupyterhub", service = "proxy-public", port = 80 }] : [],
    (var.gh_token != "" && var.triage_host != "") ? [{ hostname = var.triage_host, namespace = "triage-tinkerbell", service = "triage-party", port = 8080 }] : [],
    var.extra_http_routes,
  )

  tcp_routes = (var.mc_router_enabled && length(var.minecraft) > 0) ? [{
    hostnames = [for m in var.minecraft : m.hostname]
    namespace = "mc-router"
    service   = "mc-router"
    port      = 25565
  }] : []
}

module "longhorn" {
  count      = var.longhorn_enabled ? 1 : 0
  depends_on = [module.lke]
  source     = "./modules/longhorn"
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
}

module "mc_router" {
  count        = var.mc_router_enabled && length(var.minecraft) > 0 ? 1 : 0
  depends_on   = [module.lke, module.minecraft]
  source       = "./modules/mc_router"
  service_type = var.gateway_enabled ? "ClusterIP" : "LoadBalancer"
  mappings = [
    for m in var.minecraft : {
      hostname = m.hostname
      target   = "minecraft.${m.namespace}.svc.cluster.local:${m.port}"
    }
  ]
}

module "triage" {
  count          = (var.gh_token != "" && var.triage_host != "") ? 1 : 0
  depends_on     = [module.lke]
  source         = "./modules/triage"
  gh_token       = var.gh_token
  triage_host    = var.triage_host
  create_ingress = !var.gateway_enabled
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
