variable "namespace" {
  type        = string
  default     = "gateway"
  description = "Namespace that holds the Gateway, its EnvoyProxy config, the issued TLS secrets and the optional example app. (Envoy Gateway's own controller lives in `envoy-gateway-system`.)"
}

variable "chart_version" {
  type        = string
  default     = "v1.9.1"
  description = "envoyproxy/gateway-helm chart version. Ships the Gateway API CRDs (experimental channel, so TCPRoute is included). Bump deliberately: CRD upgrades are manual with helm."
}

variable "gateway_name" {
  type        = string
  default     = "main"
  description = "Name of the single Gateway this module manages. One Gateway == one Envoy Deployment == one LoadBalancer Service == one Linode NodeBalancer."
}

variable "cluster_issuer" {
  type        = string
  default     = "letsencrypt-prod"
  description = "cert-manager ClusterIssuer used (via the gateway-shim annotation) to issue a certificate per HTTPS listener."
}

variable "http_routes" {
  type = list(object({
    hostname        = string
    namespace       = string
    service         = string
    port            = number
    request_timeout = optional(string, "0s")
  }))
  default     = []
  description = <<-EOS
    HTTP(S) hosts to expose. For each entry the module creates an HTTPS
    listener on 443 with `hostname`, a cert-manager-issued certificate, and
    an HTTPRoute in `namespace` forwarding to `service:port`. Plain HTTP on 80
    is redirected to HTTPS for every host. `request_timeout` is the Gateway
    API HTTPRoute `timeouts.request`; the default `0s` disables it (websocket
    / long-poll friendly, matches the old 1800s nginx read timeout in
    practice).
  EOS
}

variable "tcp_routes" {
  type = list(object({
    hostnames = list(string) # DNS names external-dns should publish for this listener
    namespace = string
    service   = string
    port      = number
  }))
  default     = []
  description = <<-EOS
    Raw TCP backends exposed on `tcp_port` (a single TCP listener; the
    backend does its own demux, e.g. mc-router routing Minecraft by handshake
    hostname). Each entry becomes a TCPRoute in `namespace` with the given
    hostnames published by external-dns against the Gateway address.
  EOS
}

variable "tcp_port" {
  type        = number
  default     = 25565
  description = "External port of the TCP listener used by `tcp_routes`."
}

variable "ipv6_ingress" {
  type        = bool
  default     = true
  description = "Ask ccm-linode to publish the NodeBalancer's IPv6 address too (`linode-loadbalancer-enable-ipv6-ingress`). Frontend only; no dual-stack cluster required. external-dns then publishes AAAA records alongside A."
}

variable "example_host" {
  type        = string
  default     = ""
  description = "If set, deploy a tiny `whoami` app in the module namespace and expose it at this hostname. Handy smoke test: it echoes the request headers it received."
}

variable "external_traffic_policy" {
  type        = string
  default     = "Cluster"
  description = <<-EOS
    `externalTrafficPolicy` on the Envoy data-plane Service. Envoy Gateway's
    own default is `Local`, which makes a node's NodePort answer only when an
    Envoy pod runs on that node — so the NodeBalancer marks every other node
    down and a single-replica gateway is one node-recycle away from an outage.
    `Local` preserves the client source IP, but behind a Linode NodeBalancer
    the source is the NB anyway, so it buys nothing here. `Cluster` lets every
    node forward to Envoy via kube-proxy: all NB backends healthy.
  EOS
  validation {
    condition     = contains(["Cluster", "Local"], var.external_traffic_policy)
    error_message = "external_traffic_policy must be Cluster or Local."
  }
}

variable "replicas" {
  type        = number
  default     = 2
  description = "Envoy data-plane replicas. 2 so a single node recycle (LKE upgrades cycle nodes) never leaves the cluster without an entrypoint; a preferred anti-affinity spreads them across nodes when the pool has more than one."
}
