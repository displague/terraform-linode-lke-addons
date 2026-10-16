# Linode COSI driver (Container Object Storage Interface) — provisions Linode
# Object Storage buckets and S3 credentials from Kubernetes BucketClaim and
# BucketAccess resources.
#
# Installs:
#   - Upstream COSI CRDs (`bucketclasses`, `bucketclaims`, `buckets`,
#     `bucketaccessclasses`, `bucketaccesses` under `objectstorage.k8s.io`)
#     and `container-object-storage-controller` in
#     `container-object-storage-system` (v0.2.2).
#   - A scoped Linode API token (`object_storage:read_write`).
#   - The `linode-cosi-driver` Helm chart (`docker.io/linode/linode-cosi-driver`
#     + `objectstorage-sidecar`).
#   - Default `BucketClass` and `BucketAccessClass` resources (when
#     `var.create_default_classes` is true) plus any entries in
#     `var.bucket_classes` / `var.bucket_access_classes`.
#
# https://github.com/linode/linode-cosi-driver

locals {
  cosi_controller_documents = [
    for d in split("\n---\n", file("${path.module}/assets/cosi-controller.yaml")) : chomp(d)
    if trimspace(d) != ""
  ]

  default_bucket_classes = var.create_default_classes ? {
    "linode-objectstorage" = {
      region                   = var.region
      deletion_policy          = "Delete"
      acl                      = "private"
      cors                     = "disabled"
      cleanup                  = null
      endpoint_type            = null
      endpoint_type_preference = null
      policy                   = null
    }
    "linode-objectstorage-retain" = {
      region                   = var.region
      deletion_policy          = "Retain"
      acl                      = "private"
      cors                     = "disabled"
      cleanup                  = null
      endpoint_type            = null
      endpoint_type_preference = null
      policy                   = null
    }
  } : {}

  bucket_classes = merge(local.default_bucket_classes, var.bucket_classes)

  default_bucket_access_classes = var.create_default_classes ? {
    "linode-objectstorage" = {
      permissions              = "read_write"
      authentication_type      = "Key"
      endpoint_type            = null
      endpoint_type_preference = null
    }
    "linode-objectstorage-readonly" = {
      permissions              = "read_only"
      authentication_type      = "Key"
      endpoint_type            = null
      endpoint_type_preference = null
    }
  } : {}

  bucket_access_classes = merge(local.default_bucket_access_classes, var.bucket_access_classes)
}

resource "kubectl_manifest" "cosi_controller" {
  count             = length(local.cosi_controller_documents)
  server_side_apply = true
  yaml_body         = local.cosi_controller_documents[count.index]
}

resource "linode_token" "cosi" {
  label  = "linode-cosi-driver"
  scopes = "object_storage:read_write"
  expiry = var.token_expiry
}

resource "helm_release" "linode_cosi_driver" {
  depends_on       = [kubectl_manifest.cosi_controller]
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

resource "kubectl_manifest" "bucket_class" {
  for_each          = local.bucket_classes
  depends_on        = [helm_release.linode_cosi_driver]
  server_side_apply = true
  validate_schema   = false

  yaml_body = yamlencode({
    apiVersion     = "objectstorage.k8s.io/v1alpha1"
    kind           = "BucketClass"
    metadata       = { name = each.key }
    driverName     = "objectstorage.cosi.linode.com"
    deletionPolicy = each.value.deletion_policy
    parameters = merge(
      {
        "cosi.linode.com/v1/region" = each.value.region
        "cosi.linode.com/v1/acl"    = each.value.acl
        "cosi.linode.com/v1/cors"   = each.value.cors
      },
      each.value.cleanup != null ? { "cosi.linode.com/v1/cleanup" = each.value.cleanup } : {},
      each.value.endpoint_type != null ? { "cosi.linode.com/v1/endpoint-type" = each.value.endpoint_type } : {},
      each.value.endpoint_type_preference != null ? { "cosi.linode.com/v1/endpoint-type-preference" = each.value.endpoint_type_preference } : {},
      each.value.policy != null ? { "cosi.linode.com/v1/policy" = each.value.policy } : {},
    )
  })
}

resource "kubectl_manifest" "bucket_access_class" {
  for_each          = local.bucket_access_classes
  depends_on        = [helm_release.linode_cosi_driver]
  server_side_apply = true
  validate_schema   = false

  yaml_body = yamlencode({
    apiVersion         = "objectstorage.k8s.io/v1alpha1"
    kind               = "BucketAccessClass"
    metadata           = { name = each.key }
    driverName         = "objectstorage.cosi.linode.com"
    authenticationType = each.value.authentication_type
    parameters = merge(
      {
        "cosi.linode.com/v1/permissions" = each.value.permissions
      },
      each.value.endpoint_type != null ? { "cosi.linode.com/v1/endpoint-type" = each.value.endpoint_type } : {},
      each.value.endpoint_type_preference != null ? { "cosi.linode.com/v1/endpoint-type-preference" = each.value.endpoint_type_preference } : {},
    )
  })
}
