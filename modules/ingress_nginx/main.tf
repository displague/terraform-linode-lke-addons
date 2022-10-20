# https://artifacthub.io/packages/helm/ingress-nginx/ingress-nginx
resource "helm_release" "ingress_nginx" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = "ingress-nginx"
  create_namespace = true

  set {
    name  = "controller.config.use-proxy-protocol"
    value = true
  }
  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/linode-loadbalancer-proxy-protocol"
    value = "v2"
  }
  set {
    name  = "controller.ingressClassResource.default"
    value = true
  }
  set {
    name  = "defaultBackend.enabled"
    value = true
  }
  set {
    name  = "defaultBackend.annotations.service\\.beta\\.kubernetes\\.io/linode-loadbalancer-proxy-protocol"
    value = "v2"
  }

  # enable legacy fully automated kubernetes.io/tls-acme: "true" annotations
  #set {
  #name="ingressShim.defaultIssuerName"
  #value="letsencrypt-prod"
  #}
  #set {
  #name="ingressShim.defaultIssuerKind"
  #value="ClusterIssuer"
  #}
  #set {
  #name="ingressShim.defaultIssuerGroup"
  #value="cert-manager.io"
  #}
}

data "kubectl_path_documents" "manifests" {
  pattern = "${path.module}/assets/hairpin-proxy.yaml"
}

resource "kubectl_manifest" "manifests" {
  # for_each = data.kubectl_path_documents.manifests.documents
  # yaml_body = each.value
  depends_on = [helm_release.ingress_nginx]
  count      = 9 # hard-coding is a work-around. TF can't use a data source derived count in 1 pass.
  yaml_body  = data.kubectl_path_documents.manifests.documents[count.index]
}

data "kubectl_path_documents" "example" {
  pattern = "${path.module}/assets/example.yaml"
  vars = {
    example_host = var.example_host
  }

}

resource "kubectl_manifest" "example" {
  depends_on = [helm_release.ingress_nginx]
  # for_each = data.kubectl_path_documents.manifests.documents
  # yaml_body = each.value
  count     = length(var.example_host) > 0 ? 1 : 0 # hard-coding is a work-around
  yaml_body = data.kubectl_path_documents.example.documents[count.index]
}

