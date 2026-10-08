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
