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

variable "stack_type" {
  type        = string
  default     = null
  description = <<-EOS
    Cluster IP stack. `"ipv4"` (default, single-stack) or `"dual"` (dual-stack
    v4+v6). Leaving `null` matches the pre-feature LKE behavior.

    Fresh-cluster-only: verified against the API that `stack_type` is not
    editable on an existing cluster. Only meaningful when this module is
    provisioning a new cluster.
  EOS

  validation {
    condition     = var.stack_type == null || contains(["ipv4", "dual"], coalesce(var.stack_type, "ipv4"))
    error_message = "stack_type must be null, \"ipv4\", or \"dual\"."
  }
}

variable "vpc_id" {
  type        = number
  default     = null
  description = <<-EOS
    Linode VPC to place the cluster in. Requires `subnet_id` alongside.
    Fresh-cluster-only: moving an existing cluster onto a VPC would require
    recreate. Use with the `linode_vpc` / `linode_vpc_subnet` resources.
  EOS
}

variable "subnet_id" {
  type        = number
  default     = null
  description = <<-EOS
    Linode VPC subnet the cluster's nodes attach to. Pairs with `vpc_id`.
    Fresh-cluster-only (see `vpc_id`).
  EOS
}

variable "pool_firewall_id" {
  type        = number
  default     = null
  description = <<-EOS
    Cloud Firewall to attach to the node pool. Pass the id of a
    `linode_firewall` resource. Editable on a live pool — `terraform apply`
    attaches / detaches without a node cycle. Free of charge on Linode.
  EOS
}

variable "pool_disk_encryption" {
  type        = string
  default     = null
  description = <<-EOS
    Local disk encryption at rest on the node pool. `"enabled"` or
    `"disabled"`.

    Fresh-pool-only: the Linode API rejects updates to this on an existing
    pool. To turn encryption on for a running cluster you need to add a new
    pool with `disk_encryption = "enabled"`, drain workloads onto it, and
    delete the old pool. See
    https://techdocs.akamai.com/cloud-computing/docs/local-disk-encryption
  EOS

  validation {
    condition     = var.pool_disk_encryption == null || contains(["enabled", "disabled"], coalesce(var.pool_disk_encryption, "disabled"))
    error_message = "pool_disk_encryption must be null, \"enabled\", or \"disabled\"."
  }
}
