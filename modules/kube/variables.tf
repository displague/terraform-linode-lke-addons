variable "lke_config" {}
variable "k8s_version" { default = "1.36" }
variable "min_count" { default = 1 }
variable "max_count" { default = 3 }

variable "control_plane_acl" {
  type = object({
    enabled = bool
    ipv4    = optional(list(string), [])
    ipv6    = optional(list(string), [])
  })
  default     = null
  description = <<-EOS
    Optional control-plane ACL configuration. Leave `null` to *not* manage
    the ACL from terraform (recommended if you're setting it via the
    Cloud UI or the Linode API directly).

    When non-null:
    - `enabled = true` locks the API to the given ipv4/ipv6 lists. An empty
      allow list with `enabled = true` blackholes the API — Linode's 2025
      rollout defaulted many accounts into exactly this state, so if you
      opt in here, always pass at least one CIDR.
    - `enabled = false` explicitly removes any existing ACL (open access).

    See docs: https://techdocs.akamai.com/cloud-computing/docs/control-plane-acls
  EOS
}
