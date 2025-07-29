resource "linode_token" "external_dns" {
  label  = "external-dns"
  scopes = "domains:read_write"
  expiry = var.external_dns_token_expiry
}

resource "kubernetes_namespace" "external_dns" {
  metadata { name = "external-dns" }
}

resource "kubernetes_secret" "external_dns" {
  metadata {
    name      = "linode-external-dns"
    namespace = kubernetes_namespace.external_dns.metadata[0].name
  }

  data = {
    "linode_api_token" = linode_token.external_dns.token
  }
}


# https://artifacthub.io/packages/helm/bitnami/external-dns
resource "helm_release" "external_dns" {
  name              = "external-dns"
  repository        = "https://charts.bitnami.com/bitnami"
  chart             = "external-dns"
  namespace         = kubernetes_namespace.external_dns.metadata[0].name
  force_update      = true
  dependency_update = true

  set {
    name  = "provider"
    value = "linode"
  }

  set {
    name  = "linode.secretName"
    value = kubernetes_secret.external_dns.metadata[0].name
  }
}
