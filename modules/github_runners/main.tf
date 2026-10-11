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
  repository = "oci://ghcr.io/actions/actions-runner-controller-charts"
  secret     = "arc-github"
}

resource "kubernetes_namespace_v1" "controller" {
  metadata {
    name = var.controller_namespace
  }
}

resource "kubernetes_namespace_v1" "runners" {
  metadata {
    name = var.runners_namespace
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
      spec = merge(
        { imagePullSecrets = [for s in var.image_pull_secrets : { name = s }] },
        merge([for _ in local.cache_on : {
          initContainers = [
            {
              name         = "init-dind-externals"
              image        = var.runner_image
              command      = ["cp", "-r", "/home/runner/externals/.", "/home/runner/tmpDir/"]
              volumeMounts = [{ name = "dind-externals", mountPath = "/home/runner/tmpDir" }]
            },
            {
              name  = "dind"
              image = "docker:dind"
              args = [
                "dockerd", "--host=unix:///var/run/docker.sock", "--group=$(DOCKER_GROUP_GID)",
                "--registry-mirror=http://${local.cache_host}", "--insecure-registry=${local.cache_host}",
              ]
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
          ]
          volumes = [{ name = "work", emptyDir = {} }, { name = "dind-sock", emptyDir = {} }, { name = "dind-externals", emptyDir = {} }]
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
            merge([for _ in local.cache_on : {
              env = [
                { name = "DOCKER_HOST", value = "unix:///var/run/docker.sock" },
                { name = "RUNNER_WAIT_FOR_DOCKER_IN_SECONDS", value = "120" },
              ]
              volumeMounts = [
                { name = "work", mountPath = "/home/runner/_work" },
                { name = "dind-sock", mountPath = "/var/run" },
              ]
            }]...)
          )]
        }
      )
    }
    },
    # With the image cache, the chart's dind template is spelled out (above)
    # so the Docker daemon can take mirror flags; otherwise the chart builds it.
    merge([for _ in local.cache_off : { containerMode = { type = "dind" } }]...)
  ))]
}

# ---------- optional pull-through image cache ----------
locals {
  cache_enabled = var.image_cache.enabled
  # One-element lists for merge([for _ in ... : {...}]...), so optional
  # blocks of different shapes can be merged in only when needed.
  cache_on   = local.cache_enabled ? [1] : []
  cache_off  = local.cache_enabled ? [] : [1]
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
