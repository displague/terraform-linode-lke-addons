# https://artifacthub.io/packages/helm/cert-manager/cert-manager
resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  namespace        = "cert-manager"
  create_namespace = true

  set = [{
    name  = "installCRDs"
    value = true
  }]
}

resource "kubectl_manifest" "cert_manager_issuer_prod" {
  depends_on      = [helm_release.cert_manager]
  yaml_body       = templatefile("${path.module}/assets/cert-manager-prod.yaml", { issuer_email = var.issuer_email })
  validate_schema = false
}

resource "kubectl_manifest" "cert_manager_issuer_staging" {
  depends_on      = [helm_release.cert_manager]
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

