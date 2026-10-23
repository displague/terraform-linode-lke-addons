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

variable "toolchain_cache" {
  type = object({
    enabled   = optional(bool, false)
    host_path = optional(string, "/var/cache/github-runners")
  })
  default     = {}
  description = <<-EOS
    A per-node cache directory (hostPath) mounted into every runner pod for
    toolchains that jobs otherwise download each time: uv's package cache
    and Python installs, Playwright browsers, npm's cache and the Actions
    tool cache (setup-node, setup-uv). These tools lock their caches, so
    concurrent jobs on a node are safe; a replaced node starts cold. Jobs can
    write to it, so a job could poison it for later jobs on that node: use
    it only for trusted (private) repositories.
  EOS
}

variable "network_policy" {
  type = object({
    enabled = optional(bool, true)
    private_cidrs = optional(list(string), [
      "10.0.0.0/8",
      "172.16.0.0/12",
      "192.168.0.0/16",
      "100.64.0.0/10",
      "169.254.0.0/16",
    ])
    blocked_cidrs = optional(list(string), [])
  })
  default     = {}
  description = <<-EOS
    NetworkPolicies for the runners namespace (the cluster's CNI must
    enforce them, as Calico does). Runner pods accept no inbound traffic;
    outbound they reach cluster DNS, the image cache and any IPv4 address
    outside `private_cidrs` and `blocked_cidrs`. `private_cidrs` (RFC 1918,
    CGNAT, link-local) covers pod, Service and private node networks and
    cloud metadata; add anything that answers on a public address, such as
    the nodes' public IPs or the Kubernetes API endpoint, to `blocked_cidrs`.
  EOS
}

variable "automount_service_account_token" {
  type        = bool
  default     = false
  description = "Mount a ServiceAccount token into runner pods. Runners in dind mode don't use the Kubernetes API, so this stays off unless a job needs one."
}

variable "pod_security" {
  type = object({
    enforce = optional(string)
    warn    = optional(string, "baseline")
    audit   = optional(string, "baseline")
  })
  default     = {}
  description = <<-EOS
    Pod Security Admission levels (`privileged`, `baseline`, `restricted`)
    for the runners namespace; `null` leaves a mode unset. The dind sidecar
    is privileged, so `enforce` can be at most `privileged` here; enforcing
    `baseline` needs runners without dind (`containerMode` kubernetes).
  EOS
}
