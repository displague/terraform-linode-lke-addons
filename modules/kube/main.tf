resource "linode_lke_cluster" "lke" {
  label       = "lke.tf"
  k8s_version = var.k8s_version
  region      = "us-central"
  tags        = ["lke", "terraform"]

  # stack_type is set at cluster creation. Verified against the live API:
  # changing stack_type on an existing cluster does not take effect — the
  # attribute is effectively fresh-cluster-only. Leaving it null keeps the
  # existing behavior (IPv4-only on legacy clusters). Set to "dual" on a
  # cluster you're about to *create* to get dual-stack IPv4/IPv6.
  stack_type = var.stack_type

  # VPC integration. Both attributes are also fresh-cluster-only in practice
  # (moving a running cluster onto a VPC would require recreate). Leave null
  # to keep the current classic-networking cluster untouched.
  vpc_id    = var.vpc_id
  subnet_id = var.subnet_id

  pool {
    type  = "g6-standard-2"
    count = var.min_count

    autoscaler {
      min = var.min_count
      max = var.max_count
    }

    # Cloud Firewall attachment on the node pool. Editable on a live pool:
    # `terraform apply` on an existing cluster will attach/detach the
    # firewall without cycling the nodes.
    firewall_id = var.pool_firewall_id

    # Disk encryption at rest. The Linode API rejects updates to this on an
    # *existing* pool ("disk_encryption is not an editable field"), so this
    # setting only takes effect for a freshly-provisioned pool — either at
    # cluster create time, or when you rotate the pool via add-new /
    # drain-old / delete-old.
    disk_encryption = var.pool_disk_encryption
  }

  # Manage the control-plane ACL when the caller opts in. Passing a null
  # (`var.control_plane_acl == null`) leaves the ACL untouched — the safe
  # default when the ACL is already being managed outside terraform.
  control_plane {
    high_availability = false

    dynamic "acl" {
      for_each = var.control_plane_acl != null ? [var.control_plane_acl] : []
      content {
        enabled = acl.value.enabled
        dynamic "addresses" {
          for_each = acl.value.enabled ? [1] : []
          content {
            ipv4 = acl.value.ipv4
            ipv6 = acl.value.ipv6
          }
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [
      pool[0].count,
    ]
  }
}

resource "local_file" "lke_config" {
  depends_on      = [linode_lke_cluster.lke]
  content         = base64decode(linode_lke_cluster.lke.kubeconfig)
  filename        = var.lke_config
  file_permission = "0660"
}
