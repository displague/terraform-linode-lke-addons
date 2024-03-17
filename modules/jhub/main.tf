resource "kubernetes_namespace" "jupyterhub" {
  metadata { name = "jupyterhub" }
}

# https://artifacthub.io/packages/helm/bitnami/external-dns
resource "helm_release" "jupyterhub" {
  name              = "jupyterhub"
  repository        = "https://jupyterhub.github.io/helm-chart/"
  chart             = "jupyterhub"
  namespace         = kubernetes_namespace.jupyterhub.metadata[0].name
  force_update      = true
  dependency_update = true

  values = [
    <<-EOT
    ingress:
      enabled: true
      hosts:
      - ${var.hostname}
      tls:
        - hosts:
          - ${var.hostname}
          secretName: ${var.hostname}-crt
  EOT
  ]

  #set {
  #  name = "ingress.tls"
  #  value = jsonencode([{
  #    hosts = [var.hostname]
  #    secretName = "${var.hostname}-crt"
  #  }])
  #}

  #set {
  #  name  = "ingress.enabled"
  #  value = "true"
  #}

  set {
    name  = "hub.db.type"
    value = "sqlite-pvc"
  }

  set {
    name  = "ingress.annotations.cert-manager\\.io/cluster-issuer"
    value = "letsencrypt-prod"
  }

  #  set {
  #    name = "ingress.annotations.kubernetes\\.io/ingress\\.class"
  #    value = "nginx"
  #  }

  set {
    name  = "ingress.annotations.nginx\\.ingress\\.kubernetes\\.io/proxy-body-size"
    value = "1024m"
  }

  set {
    name  = "ingress.annotations.nginx\\.ingress\\.kubernetes\\.io/proxy-connect-timeout"
    value = "30"
    type  = "string"
  }

  set {
    name  = "ingress.annotations.nginx\\.ingress\\.kubernetes\\.io/proxy-read-timeout"
    value = "1800"
    type  = "string"
  }

  set {
    name  = "ingress.annotations.nginx\\.ingress\\.kubernetes\\.io/proxy-send-timeout"
    value = "1800"
    type  = "string"
  }

  set {
    name  = "ingress.ingressClassName"
    value = "nginx"
  }
  set {
    name  = "ingress.annotations.use-proxy-protocol"
    value = "true"
    type  = "string"
  }

  set {
    name  = "hub.config.Authenticator.auth_login"
    value = true
  }

  set {
    name  = "hub.config.GitHubOAuthenticator.client_id"
    value = var.client_id
  }

  set_sensitive {
    name  = "hub.config.GitHubOAuthenticator.client_secret"
    value = var.client_secret
  }

  set {
    name  = "hub.config.GitHubOAuthenticator.admin_users"
    value = join(",", var.gh_admin_users)
  }

  set {
    name  = "hub.config.GitHubOAuthenticator.oauth_callback_url"
    value = "https://${var.hostname}/hub/oauth_callback"
  }

  set {
    name  = "hub.config.JupyterHub.authenticator_class"
    value = "github"
  }

  set {
    name  = "hub.db.pvc.storageClassName"
    value = "linode-block-storage-retain"
  }

  set {
    name  = "hub.db.pvc.volumeName"
    value = var.hub_db_volume
  }

  set {
    name  = "hub.config.JupyterHub.admin_access"
    value = false
  }
}
