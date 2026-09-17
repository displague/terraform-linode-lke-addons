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

data "kubectl_path_documents" "linode_webhook" {
  pattern = "${path.module}/assets/linode-webhook.yaml"
}

resource "kubectl_manifest" "linode_webhook" {
  depends_on = [
    helm_release.cert_manager,
    kubernetes_secret.linode_credentials
  ]
  count     = 14
  yaml_body = data.kubectl_path_documents.linode_webhook.documents[count.index]
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

