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

  values = [yamlencode({
    githubConfigUrl    = each.value.config_url
    githubConfigSecret = kubernetes_secret_v1.github.metadata[0].name
    runnerScaleSetName = each.key
    minRunners         = each.value.min_runners
    maxRunners         = each.value.max_runners
    containerMode      = { type = "dind" }
    controllerServiceAccount = {
      namespace = kubernetes_namespace_v1.controller.metadata[0].name
      name      = "arc-gha-rs-controller"
    }
    template = {
      spec = {
        imagePullSecrets = [for s in var.image_pull_secrets : { name = s }]
        containers = [{
          name    = "runner"
          image   = var.runner_image
          command = ["/home/runner/run.sh"]
          resources = {
            requests = { cpu = each.value.cpu_request, memory = each.value.memory_request }
            limits   = { memory = each.value.memory_limit }
          }
        }]
      }
    }
  })]
}
