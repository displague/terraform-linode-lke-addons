variable "chart_version" {
  type        = string
  description = "itzg/mc-router chart version. Pinned so upstream changes don't silently roll out."
  default     = "1.5.0"
}

variable "namespace" {
  type        = string
  description = "Kubernetes namespace to install mc-router into."
  default     = "mc-router"
}

variable "mappings" {
  type = list(object({
    hostname = string # external hostname minecraft clients dial (e.g. "mc1.example.com")
    target   = string # k8s Service address:port (e.g. "minecraft.minecraft.svc.cluster.local:25565")
  }))
  description = <<-EOS
    Mapping list turned into `minecraftRouter.mappings` on the itzg/mc-router
    chart. Each entry routes an inbound Minecraft handshake for the given
    hostname to the matching in-cluster Service.
  EOS
}

variable "external_port" {
  type        = number
  description = "External Minecraft port exposed by the mc-router LoadBalancer Service."
  default     = 25565
}


variable "service_type" {
  type        = string
  default     = "LoadBalancer"
  description = "Service type for mc-router. `LoadBalancer` = its own NodeBalancer (external-dns hostnames published from the Service). `ClusterIP` = sit behind a Gateway API TCPRoute (modules/gateway), which then owns the hostnames."
  validation {
    condition     = contains(["LoadBalancer", "ClusterIP"], var.service_type)
    error_message = "service_type must be LoadBalancer or ClusterIP."
  }
}

variable "proxy_protocol" {
  type        = string
  default     = "off"
  description = <<-EOS
    Real client IPs at mc-router via PROXY protocol: `off`, `accept` or `on`.
    `accept` makes mc-router accept an optional PROXY header
    (RECEIVE_PROXY_PROTOCOL), so its connection logs and allow/deny lists see
    the client's address. `on` also has the NodeBalancer send PROXY v2 when
    `service_type = "LoadBalancer"`; behind a Gateway the sender is Envoy
    (modules/gateway `tcp_routes[*].proxy_protocol`). Roll out `accept` before
    `on`. mc-router never forwards the header to the minecraft servers, which
    still see mc-router's pod IP (vanilla servers can't read PROXY).
  EOS
  validation {
    condition     = contains(["off", "accept", "on"], var.proxy_protocol)
    error_message = "proxy_protocol must be off, accept or on."
  }
}

variable "trusted_proxies" {
  type        = list(string)
  default     = []
  description = "CIDRs whose PROXY headers mc-router honours (TRUSTED_PROXIES); headers from anywhere else are discarded. Empty trusts every source, which is fine for a ClusterIP Service only reachable in-cluster. Ignored when `proxy_protocol = \"off\"`."
}

variable "image_pull_secrets" {
  type        = list(string)
  default     = []
  description = "Names of pull Secrets in the release namespace (e.g. Docker Hub credentials), passed to the chart's imagePullSecrets."
}

variable "image_tag" {
  type        = string
  default     = "1.49.0"
  description = "itzg/mc-router image tag. The chart defaults to `latest` with pullPolicy Always, so every restart could change the router; pinned instead. Autoscale needs 1.48.0 or later (only player logins reset the idle timer; status pings don't keep a server awake)."
}

variable "autoscale" {
  type = object({
    enabled = optional(bool, false)
    # Namespaces whose StatefulSet mc-router may scale (Role per namespace).
    namespaces   = optional(list(string), [])
    down_after   = optional(string, "10m")
    asleep_motd  = optional(string, "Asleep - join to wake it, then join again in ~2 min")
    loading_motd = optional(string, "Waking up - join again in a minute")
  })
  default     = {}
  description = <<-EOS
    Scale idle minecraft servers to zero. When `enabled`, mc-router discovers
    its routes from Service annotations (`mc-router.itzg.me/externalServerName`,
    set by modules/minecraft `mc_router_discovery`) instead of `mappings`,
    wakes a StatefulSet-backed server on a player login and scales it back to 0
    `down_after` the last player leaves. `namespaces` lists the namespaces whose
    StatefulSet it may scale; servers elsewhere are routed but never scaled.
    Changing `namespaces` restarts the router so the switched servers' idle
    timers start (a hash of the list is a pod annotation).
  EOS
}
