variable "external_dns_token_expiry" {
  description = "Expiry date for the Linode API token used by external-dns. RFC3339 format."
  type        = string
}
variable "linode_token" {
  type        = string
  description = "Your Linode API Authentication Token."
}
variable "issuer_email" {
  type        = string
  description = "An email address for ACME certificate registration."
}
variable "example_host" {
  type        = string
  description = "If set, an ingress will be created with this hostname used. The domain should be one managed by your Linode account."
}

variable "k8s_version" {
  type        = string
  description = "LKE K8s Version. Keep within Linode's currently-supported window (`linode-cli lke versions-list`)."
  default     = "1.36"
}

variable "longhorn_enabled" {
  type        = bool
  default     = false
  description = "Whether Longhorn should be installed"
}

variable "gh_token" {
  type        = string
  default     = ""
  description = "GH token for triage party"
  sensitive   = true
}
variable "gh_admin_users" {
  default     = []
  description = "GH admin_users for JupyterHub"
  type        = list(string)
}

variable "triage_host" {
  type        = string
  default     = ""
  description = "hostname where triage party will reside"
}

variable "mc_router_enabled" {
  type        = bool
  description = <<-EOS
    When true, deploy `modules/mc_router` (a single LoadBalancer that routes
    all minecraft traffic by handshake hostname) and force every entry in
    `var.minecraft` to `service_type = ClusterIP`. Consolidates N per-server
    NodeBalancers down to one. Requires clients to keep dialing the same
    per-server hostnames.
  EOS
  default     = false
}


variable "minecraft" {
  type = list(object(
    {
      namespace    = string
      port         = number
      ops          = string
      motd         = string
      hostname     = string
      claim        = string
      mc_version   = optional(string, "LATEST")
      service_type = optional(string, "LoadBalancer")
    }
  ))
  description = <<-EOT
A list of minecraft servers to deploy. Each object should have the following fields:
- namespace: the namespace of the minecraft server
- port: the port to run the minecraft server on
- ops: a list of minecraft usernames that will receive ops
- motd: the minecraft MOTD
- hostname: the hostname where minecraft will run
- claim: existing claim
- mc_version: (optional) itzg image `VERSION` — pin to a specific minecraft
  version like "1.21.8" when restoring a world from a much older DataVersion.
  Defaults to "LATEST".
EOT
}

variable "jhub_hostname" {
  type        = string
  default     = ""
  description = "hostname for jupyter hub"
}

variable "jhub_client_id" {
  type        = string
  default     = ""
  description = "GH client_id for jhub"
}
variable "jhub_client_secret" {
  type        = string
  default     = ""
  description = "GH client_secret for jhub"
}
variable "jhub_db_volume" {
  type        = string
  default     = ""
  description = "PVC name for Hub DB Volume"
}

variable "lke_acl_enabled" {
  type        = bool
  default     = false
  description = <<-EOS
    Manage the LKE control-plane ACL from terraform. When `false` the module
    leaves the ACL untouched (Cloud UI / API manages it). When `true`,
    terraform applies the enabled=true policy with the ipv4 / ipv6 lists
    below plus (optionally) the caller's current public IP.
  EOS
}

variable "lke_acl_allow_my_ip" {
  type        = bool
  default     = false
  description = <<-EOS
    Also add whatever public IPv4 the terraform-runner has right now to the
    ACL allow list. Uses `data "http"` against ipv4.icanhazip.com. Handy for
    home / office runners on residential NAT — but be aware the IP can
    change, in which case a subsequent apply is needed to keep access.
    Ignored if `lke_acl_enabled = false`.
  EOS
}

variable "lke_acl_ipv4" {
  type        = list(string)
  default     = []
  description = "IPv4 CIDRs to allow through the LKE control-plane ACL. Ignored if `lke_acl_enabled = false`."
}

variable "lke_acl_ipv6" {
  type        = list(string)
  default     = []
  description = "IPv6 CIDRs to allow through the LKE control-plane ACL. Ignored if `lke_acl_enabled = false`."
}

variable "gateway_enabled" {
  type        = bool
  default     = true
  description = <<-EOS
    Front the cluster with a single Gateway API Gateway (modules/gateway,
    Envoy Gateway) instead of ingress-nginx + a separate mc-router
    LoadBalancer. When true: HTTPRoutes are created for the jhub / triage /
    example hosts and `extra_http_routes`, a TCPRoute fronts mc-router
    (which drops to ClusterIP), cert-manager's gateway-shim is enabled, and
    external-dns switches to the gateway-httproute / gateway-tcproute
    sources. This is the cluster's only entrypoint; set false only if you
    bring your own ingress.
  EOS
}

variable "gateway_ipv6_ingress" {
  type        = bool
  default     = true
  description = "Publish an IPv6 address on the Gateway's NodeBalancer too (frontend only; no dual-stack cluster needed). external-dns then adds AAAA records."
}

variable "extra_http_routes" {
  type = list(object({
    hostname        = string
    namespace       = string
    service         = string
    port            = number
    request_timeout = optional(string, "0s")
  }))
  default     = []
  description = "Additional HTTP(S) hosts to route through the Gateway to an existing in-cluster Service (`namespace/service:port`). Each gets its own HTTPS listener + certificate."
}

