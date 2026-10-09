# https://artifacthub.io/packages/helm/cert-manager/cert-manager
resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  namespace        = "cert-manager"
  create_namespace = true

  set = concat([{
    name  = "installCRDs"
    value = true
    }, {
    name  = "extraArgs[0]"
    value = "--feature-gates=ACMEHTTP01IngressPathTypeExact=false"
    }],
    var.gateway_api_enabled ? [{
      name  = "config.gatewayAPI.enabled"
      value = "true"
    }] : [],
  )
}

resource "kubernetes_secret" "linode_credentials" {
  metadata {
    name      = "linode-credentials"
    namespace = helm_release.cert_manager.namespace
  }

  data = {
    token = var.linode_api_token
  }
}

# A plain file() split, not a kubectl_path_documents data source: the root
# module depends_on module.gateway, so any pending gateway change deferred
# that data source to apply time and showed all 14 manifests as changed.
locals {
  linode_webhook_documents = [
    for d in split("\n---\n", file("${path.module}/assets/linode-webhook.yaml")) : chomp(d)
    if trimspace(d) != ""
  ]
}

resource "kubectl_manifest" "linode_webhook" {
  depends_on = [
    helm_release.cert_manager,
    kubernetes_secret.linode_credentials
  ]
  count     = length(local.linode_webhook_documents)
  yaml_body = local.linode_webhook_documents[count.index]
}

resource "kubectl_manifest" "cert_manager_issuer_prod" {
  depends_on      = [kubectl_manifest.linode_webhook]
  yaml_body       = templatefile("${path.module}/assets/cert-manager-prod.yaml", { issuer_email = var.issuer_email })
  validate_schema = false
}

resource "kubectl_manifest" "cert_manager_issuer_staging" {
  depends_on      = [kubectl_manifest.linode_webhook]
  yaml_body       = templatefile("${path.module}/assets/cert-manager-staging.yaml", { issuer_email = var.issuer_email })
  validate_schema = false
}



# kubernetes_manifest uses server-side apply and the CRD is not ready at time of check
# we use kubectl_manifest to ignore the check
#
#resource "kubernetes_manifest" "cert_manager_issuer_prod" {
#  depends_on      = [helm_release.cert_manager]
#  manifest        = yamldecode(templatefile("${path.module}/assets/cert-manager-prod.yaml", { issuer_email = var.issuer_email }))
#}
#
#resource "kubernetes_manifest" "cert_manager_issuer_staging" {
#  depends_on      = [helm_release.cert_manager]
#  manifest        = yamldecode(templatefile("${path.module}/assets/cert-manager-staging.yaml", { issuer_email = var.issuer_email }))
#}

