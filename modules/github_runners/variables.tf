variable "scale_sets" {
  type = map(object({
    config_url     = string
    min_runners    = optional(number, 0)
    max_runners    = optional(number, 2)
    cpu_request    = optional(string, "500m")
    memory_request = optional(string, "1Gi")
    memory_limit   = optional(string, "3Gi")
  }))
  description = <<-EOS
    Runner scale sets, keyed by name; workflows select one with
    `runs-on: <name>`. `config_url` is the repository
    (`https://github.com/<owner>/<repo>`) or organization the runners
    register with; on a personal account, runners are per repository.
    `min_runners = 0` starts a pod only when a job is queued.
  EOS
}

variable "github_token" {
  type        = string
  default     = null
  sensitive   = true
  description = "Fine-grained personal access token with Administration read/write on each repository. Ignored when `github_app` is set."
}

variable "github_app" {
  type = object({
    app_id          = string
    installation_id = string
    private_key     = string
  })
  default     = null
  sensitive   = true
  description = "GitHub App credentials, preferred over a token. The app needs Administration read/write on the repositories."
}

variable "chart_version" {
  type        = string
  default     = "0.15.0"
  description = "Version of both ARC charts (controller and scale set), which must match."
}

variable "runner_image" {
  type        = string
  default     = "ghcr.io/actions/actions-runner:latest"
  description = "Runner image. GitHub rejects runners more than 30 days behind the latest release, so `latest` is the usual choice."
}

variable "image_pull_secrets" {
  type        = list(string)
  default     = []
  description = "Secrets in the runners namespace for pulling the runner and docker:dind images (for example Docker Hub credentials)."
}

variable "controller_namespace" {
  type    = string
  default = "arc-systems"
}

variable "runners_namespace" {
  type    = string
  default = "arc-runners"
}

variable "image_cache" {
  type = object({
    enabled       = optional(bool, false)
    size          = optional(string, "20Gi")
    storage_class = optional(string)
    image         = optional(string, "registry:2.8.3")
    ttl           = optional(string, "168h")
  })
  default     = {}
  description = <<-EOS
    A pull-through Docker Hub cache for the runners' Docker daemons: a
    `registry` in proxy mode on a persistent volume (block storage, one
    replica), set as each runner's `--registry-mirror`. The first job pulls
    an image from Docker Hub; later jobs get it from the cluster. Mirrors
    only apply to Docker Hub images (docker.io/...).
  EOS
}

variable "image_cache_upstream_credentials" {
  type = object({
    username = string
    password = string
  })
  default     = null
  sensitive   = true
  description = "Docker Hub credentials for the cache's upstream pulls (avoids anonymous rate limits)."
}
