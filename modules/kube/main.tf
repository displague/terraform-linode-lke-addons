resource "linode_lke_cluster" "lke" {
  label       = "lke.tf"
  k8s_version = var.k8s_version
  region      = "us-central"
  tags        = ["lke", "terraform"]

  pool {
    type  = "g6-standard-2"
    count = var.min_count

    autoscaler {
      min = var.min_count
      max = var.max_count
    }
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

