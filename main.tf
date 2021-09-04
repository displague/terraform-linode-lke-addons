provider "linode" {
  token = var.linode_token
}

resource "linode_lke_cluster" "lke" {
  label       = "lke.tf"
  k8s_version = "1.21"
  region      = "us-central"
  tags        = ["lke", "terraform"]

  pool {
    type  = "g6-standard-2"
    count = 3
  }
}

resource "local_file" "lke_config" {
  content         = base64decode(linode_lke_cluster.lke.kubeconfig)
  filename        = "${path.module}/lke.config"
  file_permission = "0660"
}

provider "kubernetes" {
  config_paths = [local_file.lke_config.filename]

  experiments {
    manifest_resource = true
  }
}

provider "helm" {
  kubernetes {
    config_paths = [local_file.lke_config.filename]
  }
}

resource "linode_token" "external_dns" {
  label  = "external-dns"
  scopes = "domains:read_write"
  expiry = "2025-01-01T00:00:00Z"
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

# https://artifacthub.io/packages/helm/cert-manager/cert-manager
resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  namespace        = "cert-manager"
  create_namespace = true

  set {
    name  = "installCRDs"
    value = true
  }
}

# TODO: this resource is not getting installed before the helm_release, without the CRD the GVR of the manifest is rejected
resource "kubernetes_manifest" "cert_manager_issuer_prod" {
  depends_on = [helm_release.cert_manager]
  manifest   = yamldecode(templatefile("${path.module}/assets/cert-manager-prod.yaml", { issuer_email = var.issuer_email }))
}

resource "kubernetes_manifest" "cert_manager_issuer_staging" {
  depends_on = [helm_release.cert_manager]
  manifest   = yamldecode(templatefile("${path.module}/assets/cert-manager-staging.yaml", { issuer_email = var.issuer_email }))
}
