# Autoscale RBAC, kept narrower than the chart's: with
# `minecraftRouter.autoScale.up.enabled` the chart binds a ClusterRole that
# may update and patch every StatefulSet in the cluster. Instead the chart
# keeps its services-only ClusterRole (main.tf leaves the chart flags unset
# and turns autoscale on through env), and here:
#   - cluster-wide watch/list on StatefulSets: mc-router runs one informer
#     across all namespaces (KUBE_NAMESPACE takes a single namespace), and an
#     informer needs list+watch at the scope it watches.
#   - patch, and get on the scale subresource, only in the namespaces that
#     run a scale-to-zero server.

locals {
  # The chart's ServiceAccount: fullname of release "mc-router", chart
  # "mc-router" (no fullnameOverride).
  service_account = "mc-router"
}

resource "kubernetes_cluster_role_v1" "statefulset_reader" {
  count = var.autoscale.enabled ? 1 : 0
  metadata {
    name = "mc-router-statefulset-reader"
  }
  rule {
    api_groups = ["apps"]
    resources  = ["statefulsets"]
    verbs      = ["watch", "list"]
  }
}

resource "kubernetes_cluster_role_binding_v1" "statefulset_reader" {
  count = var.autoscale.enabled ? 1 : 0
  metadata {
    name = "mc-router-statefulset-reader"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role_v1.statefulset_reader[0].metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = local.service_account
    namespace = var.namespace
  }
}

resource "kubernetes_role_v1" "scaler" {
  for_each = var.autoscale.enabled ? toset(var.autoscale.namespaces) : toset([])
  metadata {
    name      = "mc-router-scaler"
    namespace = each.value
  }
  rule {
    api_groups = ["apps"]
    resources  = ["statefulsets"]
    verbs      = ["patch"]
  }
  rule {
    api_groups = ["apps"]
    resources  = ["statefulsets/scale"]
    verbs      = ["get"]
  }
}

resource "kubernetes_role_binding_v1" "scaler" {
  for_each = kubernetes_role_v1.scaler
  metadata {
    name      = "mc-router-scaler"
    namespace = each.key
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = each.value.metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = local.service_account
    namespace = var.namespace
  }
}
