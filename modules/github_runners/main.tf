# GitHub Actions Runner Controller (ARC): ephemeral self-hosted runners that
# GitHub scales on demand. Each scale set registers with one repository (or
# organization) and is used with `runs-on: <scale set name>`. Runner pods run
# Docker in a privileged dind sidecar, so jobs can use service containers and
# build images; every job gets a fresh pod.
#
# Don't run a pipeline that manages this cluster on these runners: an upgrade
# or node recycle would kill its own runner mid-apply. And don't attach them
# to public repositories, where any fork pull request runs code here.
#
# https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners-with-actions-runner-controller

locals {
  # Memory request and limit for each scale set's dind sidecar; empty when unset.
  dind_resources = { for name, set in var.scale_sets : name => { for k, v in {
    requests = { for r, q in { memory = set.dind_memory_request } : r => q if q != null }
    limits   = { for r, q in { memory = set.dind_memory_limit } : r => q if q != null }
  } : k => v if length(v) > 0 } }
}

locals {
  repository = "oci://ghcr.io/actions/actions-runner-controller-charts"
  secret     = "arc-github"
}

resource "kubernetes_namespace_v1" "controller" {
  metadata {
    name = var.controller_namespace
  }
}

# Pod Security Admission labels. `enforce` can't be `baseline` while the dind
# sidecar is privileged (and the toolchain cache is a hostPath), so by default
# violations are only warned about and audited.
resource "kubernetes_namespace_v1" "runners" {
  metadata {
    name = var.runners_namespace
    labels = merge([for mode, level in {
      enforce = var.pod_security.enforce
      warn    = var.pod_security.warn
      audit   = var.pod_security.audit
      } : {
      "pod-security.kubernetes.io/${mode}"         = level
      "pod-security.kubernetes.io/${mode}-version" = "latest"
    } if level != null]...)
  }
}

resource "helm_release" "controller" {
  name       = "arc"
  repository = local.repository
  chart      = "gha-runner-scale-set-controller"
  version    = var.chart_version
  namespace  = kubernetes_namespace_v1.controller.metadata[0].name
}

# A GitHub App is preferred (scoped, rate limits per installation); a
# fine-grained personal access token with Administration read/write on the
# repository also works.
resource "kubernetes_secret_v1" "github" {
  metadata {
    name      = local.secret
    namespace = kubernetes_namespace_v1.runners.metadata[0].name
  }
  data = var.github_app != null ? {
    github_app_id              = var.github_app.app_id
    github_app_installation_id = var.github_app.installation_id
    github_app_private_key     = var.github_app.private_key
  } : { github_token = var.github_token }

  lifecycle {
    precondition {
      condition     = var.github_app != null || var.github_token != null
      error_message = "Set github_app or github_token for the runners to register with GitHub."
    }
  }
}

resource "helm_release" "scale_set" {
  for_each   = var.scale_sets
  depends_on = [helm_release.controller]
  name       = each.key
  repository = local.repository
  chart      = "gha-runner-scale-set"
  version    = var.chart_version
  namespace  = kubernetes_namespace_v1.runners.metadata[0].name

  values = [yamlencode(merge({
    githubConfigUrl    = each.value.config_url
    githubConfigSecret = kubernetes_secret_v1.github.metadata[0].name
    runnerScaleSetName = each.key
    minRunners         = each.value.min_runners
    maxRunners         = each.value.max_runners
    controllerServiceAccount = {
      namespace = kubernetes_namespace_v1.controller.metadata[0].name
      name      = "arc-gha-rs-controller"
    }
    template = {
      # The network policy below selects runner pods by these labels.
      metadata = { labels = local.runner_labels }
      spec = merge(
        {
          imagePullSecrets = [for s in var.image_pull_secrets : { name = s }]
          # In dind mode the runner talks to GitHub, never the Kubernetes API
          # (its registration arrives as an env var from a Secret), so it has
          # no use for a ServiceAccount token.
          automountServiceAccountToken = var.automount_service_account_token
        },
        merge([for _ in local.tmpl_on : {
          initContainers = concat([for _ in local.tool_on : {
            # hostPath directories are created root-owned; hand them to the runner user.
            name            = "toolchain-cache-owner"
            image           = var.runner_image
            command         = ["sh", "-c", "install -d -o 1001 -g 123 ${join(" ", [for k, _ in local.tool_dirs : "/cache/${k}"])}"]
            securityContext = { runAsUser = 0 }
            volumeMounts    = [{ name = "toolchain-root", mountPath = "/cache" }]
            }], [
            {
              name         = "init-dind-externals"
              image        = var.runner_image
              command      = ["cp", "-r", "/home/runner/externals/.", "/home/runner/tmpDir/"]
              volumeMounts = [{ name = "dind-externals", mountPath = "/home/runner/tmpDir" }]
            },
            merge({
              name  = "dind"
              image = "docker:dind"
              args = concat(
                ["dockerd", "--host=unix:///var/run/docker.sock", "--group=$(DOCKER_GROUP_GID)"],
                local.cache_enabled ? ["--registry-mirror=http://${local.cache_host}", "--insecure-registry=${local.cache_host}"] : [],
              )
              env             = [{ name = "DOCKER_GROUP_GID", value = "123" }]
              securityContext = { privileged = true }
              restartPolicy   = "Always"
              startupProbe    = { exec = { command = ["docker", "info"] }, initialDelaySeconds = 0, failureThreshold = 24, periodSeconds = 5 }
              volumeMounts = [
                { name = "work", mountPath = "/home/runner/_work" },
                { name = "dind-sock", mountPath = "/var/run" },
                { name = "dind-externals", mountPath = "/home/runner/externals" },
              ]
              },
              # Only when set, so existing runner pods render exactly as before.
              length(local.dind_resources[each.key]) == 0 ? {} : { resources = local.dind_resources[each.key] },
            ),
          ])
          volumes = concat(
            [{ name = "work", emptyDir = {} }, { name = "dind-sock", emptyDir = {} }, { name = "dind-externals", emptyDir = {} }],
            [for _ in local.tool_on : { name = "toolchain-root", hostPath = { path = var.toolchain_cache.host_path, type = "DirectoryOrCreate" } }],
            flatten([for _ in local.tool_on : [for k, _ in local.tool_dirs : { name = k, hostPath = { path = "${var.toolchain_cache.host_path}/${k}", type = "DirectoryOrCreate" } }]]),
          )
        }]...),
        {
          containers = [merge(
            {
              name    = "runner"
              image   = var.runner_image
              command = ["/home/runner/run.sh"]
              resources = {
                requests = { cpu = each.value.cpu_request, memory = each.value.memory_request }
                limits   = { memory = each.value.memory_limit }
              }
            },
            merge([for _ in local.tmpl_on : {
              env = concat(
                [
                  { name = "DOCKER_HOST", value = "unix:///var/run/docker.sock" },
                  { name = "RUNNER_WAIT_FOR_DOCKER_IN_SECONDS", value = "120" },
                ],
                # setup-node/setup-uv keep their downloads in the tool cache.
                local.toolchain ? [
                  { name = "RUNNER_TOOL_CACHE", value = "/home/runner/.cache/toolcache" },
                  { name = "AGENT_TOOLSDIRECTORY", value = "/home/runner/.cache/toolcache" },
                ] : [],
              )
              volumeMounts = concat(
                [
                  { name = "work", mountPath = "/home/runner/_work" },
                  { name = "dind-sock", mountPath = "/var/run" },
                ],
                [for k, path in(local.toolchain ? local.tool_dirs : {}) : { name = k, mountPath = path }],
              )
            }]...)
          )]
        }
      )
    }
    },
    # With either cache, the chart's dind template is spelled out (above);
    # otherwise the chart builds it.
    merge([for _ in local.tmpl_off : { containerMode = { type = "dind" } }]...)
  ))]
}

# ---------- optional pull-through image cache ----------
locals {
  cache_enabled = var.image_cache.enabled
  # One-element lists for merge([for _ in ... : {...}]...), so optional
  # blocks of different shapes can be merged in only when needed.

  # The chart's dind template is spelled out when either cache needs to
  # change the pod (mirror flags, cache mounts).
  toolchain = var.toolchain_cache.enabled
  explicit  = local.cache_enabled || local.toolchain
  tmpl_on   = local.explicit ? [1] : []
  tmpl_off  = local.explicit ? [] : [1]
  tool_on   = local.toolchain ? [1] : []
  # Each tool's cache, under the runner's home.
  tool_dirs = {
    "toolchain-cache"  = "/home/runner/.cache"
    "toolchain-python" = "/home/runner/.local/share/uv"
    "toolchain-npm"    = "/home/runner/.npm"
  }
  cache_host = "registry-cache.${var.runners_namespace}.svc.cluster.local:5000"
}

resource "kubernetes_persistent_volume_claim_v1" "image_cache" {
  count = local.cache_enabled ? 1 : 0
  metadata {
    name      = "registry-cache"
    namespace = kubernetes_namespace_v1.runners.metadata[0].name
  }
  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = var.image_cache.storage_class
    resources {
      requests = { storage = var.image_cache.size }
    }
  }
  wait_until_bound = false
}

resource "kubernetes_secret_v1" "image_cache_upstream" {
  count = local.cache_enabled && var.image_cache_upstream_credentials != null ? 1 : 0
  metadata {
    name      = "registry-cache-upstream"
    namespace = kubernetes_namespace_v1.runners.metadata[0].name
  }
  data = {
    REGISTRY_PROXY_USERNAME = var.image_cache_upstream_credentials.username
    REGISTRY_PROXY_PASSWORD = var.image_cache_upstream_credentials.password
  }
}

resource "kubernetes_deployment_v1" "image_cache" {
  count = local.cache_enabled ? 1 : 0
  metadata {
    name      = "registry-cache"
    namespace = kubernetes_namespace_v1.runners.metadata[0].name
    labels    = { app = "registry-cache" }
  }
  spec {
    replicas = 1
    # One block volume, attached to one node at a time.
    strategy { type = "Recreate" }
    selector { match_labels = { app = "registry-cache" } }
    template {
      metadata { labels = { app = "registry-cache" } }
      spec {
        dynamic "image_pull_secrets" {
          for_each = var.image_pull_secrets
          content { name = image_pull_secrets.value }
        }
        container {
          name  = "registry"
          image = var.image_cache.image
          port { container_port = 5000 }
          env {
            name  = "REGISTRY_PROXY_REMOTEURL"
            value = "https://registry-1.docker.io"
          }
          env {
            name  = "REGISTRY_PROXY_TTL"
            value = var.image_cache.ttl
          }
          env {
            name  = "REGISTRY_STORAGE_DELETE_ENABLED"
            value = "true"
          }
          dynamic "env_from" {
            for_each = length(kubernetes_secret_v1.image_cache_upstream) > 0 ? [1] : []
            content {
              secret_ref { name = kubernetes_secret_v1.image_cache_upstream[0].metadata[0].name }
            }
          }
          volume_mount {
            name       = "data"
            mount_path = "/var/lib/registry"
          }
          readiness_probe {
            http_get {
              path = "/v2/"
              port = 5000
            }
          }
          resources {
            requests = { cpu = "50m", memory = "64Mi" }
            limits   = { memory = "512Mi" }
          }
        }
        volume {
          name = "data"
          persistent_volume_claim { claim_name = kubernetes_persistent_volume_claim_v1.image_cache[0].metadata[0].name }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "image_cache" {
  count = local.cache_enabled ? 1 : 0
  metadata {
    name      = "registry-cache"
    namespace = kubernetes_namespace_v1.runners.metadata[0].name
  }
  spec {
    selector = { app = "registry-cache" }
    port {
      port        = 5000
      target_port = 5000
    }
  }
}

# ---------- network isolation ----------
# Runner pods may reach cluster DNS, the image cache and the public internet,
# but not private or link-local addresses: other pods, Services, nodes'
# private interfaces or cloud metadata. Jobs and their service containers run
# in the dind sidecar, NATed onto the pod's own network namespace, so the
# pod's policy covers them too. Nothing connects into a runner pod: runners
# poll GitHub, and the ARC controller and listeners use only the Kubernetes
# and GitHub APIs.
locals {
  runner_labels  = { "app.kubernetes.io/component" = "runner", "app.kubernetes.io/part-of" = "github-runners" }
  netpol_enabled = var.network_policy.enabled
  egress_except  = concat(var.network_policy.private_cidrs, var.network_policy.blocked_cidrs)
  dns_namespace  = { "kubernetes.io/metadata.name" = "kube-system" }
}

resource "kubernetes_network_policy_v1" "runners" {
  count = local.netpol_enabled ? 1 : 0
  metadata {
    name      = "github-runners"
    namespace = kubernetes_namespace_v1.runners.metadata[0].name
  }
  spec {
    pod_selector {
      match_labels = local.runner_labels
    }
    # No ingress rules: all inbound traffic is denied.
    policy_types = ["Ingress", "Egress"]

    egress {
      to {
        namespace_selector {
          match_labels = local.dns_namespace
        }
      }
      ports {
        port     = "53"
        protocol = "UDP"
      }
      ports {
        port     = "53"
        protocol = "TCP"
      }
    }

    dynamic "egress" {
      for_each = local.cache_enabled ? [1] : []
      content {
        to {
          pod_selector {
            match_labels = { app = "registry-cache" }
          }
        }
        ports {
          port     = "5000"
          protocol = "TCP"
        }
      }
    }

    egress {
      to {
        ip_block {
          cidr   = "0.0.0.0/0"
          except = local.egress_except
        }
      }
    }
  }
}

# The Kubernetes API endpoint is a public address (that can change), so the
# ipBlock above can't exclude it. Calico can: a Service match covers the
# `kubernetes` Service's ClusterIP and its endpoints, the control plane's
# real address. Order 100 runs before Kubernetes NetworkPolicies (1000);
# other traffic falls through to them. Only created with the policy above:
# alone, a Calico policy with no allow rule would end the tier in a deny.
# A `default.` name is how Calico stores default-tier policies, and is
# still a plain name on releases without tiers.
resource "kubectl_manifest" "runners_deny_apiserver" {
  count = local.netpol_enabled && var.calico_policies ? 1 : 0
  yaml_body = yamlencode({
    apiVersion = "crd.projectcalico.org/v1"
    kind       = "NetworkPolicy"
    metadata = {
      name      = "default.github-runners-deny-apiserver"
      namespace = kubernetes_namespace_v1.runners.metadata[0].name
    }
    spec = {
      order    = 100
      selector = join(" && ", [for k, v in local.runner_labels : "${k} == '${v}'"])
      types    = ["Egress"]
      egress = [{
        action      = "Deny"
        destination = { services = { name = "kubernetes", namespace = "default" } }
      }]
    }
  })
}

# The cache takes pulls from runner pods only, and reaches out only to DNS and
# the public internet (Docker Hub).
resource "kubernetes_network_policy_v1" "image_cache" {
  count = local.netpol_enabled && local.cache_enabled ? 1 : 0
  metadata {
    name      = "registry-cache"
    namespace = kubernetes_namespace_v1.runners.metadata[0].name
  }
  spec {
    pod_selector {
      match_labels = { app = "registry-cache" }
    }
    policy_types = ["Ingress", "Egress"]

    ingress {
      from {
        pod_selector {
          match_labels = local.runner_labels
        }
      }
      ports {
        port     = "5000"
        protocol = "TCP"
      }
    }

    egress {
      to {
        namespace_selector {
          match_labels = local.dns_namespace
        }
      }
      ports {
        port     = "53"
        protocol = "UDP"
      }
      ports {
        port     = "53"
        protocol = "TCP"
      }
    }

    egress {
      to {
        ip_block {
          cidr   = "0.0.0.0/0"
          except = local.egress_except
        }
      }
    }
  }
}
