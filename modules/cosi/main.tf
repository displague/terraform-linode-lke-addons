# Linode COSI driver (Container Object Storage Interface) — provisions Linode
# Object Storage buckets and S3 credentials from Kubernetes BucketClaim and
# BucketAccess resources.
#
# Creates a Linode API token scoped to `object_storage:read_write` and installs
# the `linode-cosi-driver` Helm chart.
#
# https://github.com/linode/linode-cosi-driver

resource "linode_token" "cosi" {
  label  = "linode-cosi-driver"
  scopes = "object_storage:read_write"
  expiry = var.token_expiry
}

resource "helm_release" "linode_cosi_driver" {
  name             = "linode-cosi-driver"
  repository       = "https://linode.github.io/linode-cosi-driver"
  chart            = "linode-cosi-driver"
  version          = var.chart_version
  namespace        = var.namespace
  create_namespace = true

  values = length(var.image_pull_secrets) > 0 ? [yamlencode({
    imagePullSecrets = [for s in var.image_pull_secrets : { name = s }]
  })] : []

  set_sensitive = [{
    name  = "apiToken"
    value = linode_token.cosi.token
  }]
}
