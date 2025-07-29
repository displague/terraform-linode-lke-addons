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

  set_sensitive = [{
    name  = "hub.config.GitHubOAuthenticator.client_secret"
    value = var.client_secret
  }]

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

  set = [
    {
      name  = "hub.db.type"
      value = "sqlite-pvc"
    },
    {
      name  = "ingress.annotations.cert-manager\\.io/cluster-issuer"
      value = "letsencrypt-prod"
    },

    #  set {
    #    name = "ingress.annotations.kubernetes\\.io/ingress\\.class"
    #    value = "nginx"
    #  }
    {
      name  = "ingress.annotations.nginx\\.ingress\\.kubernetes\\.io/proxy-body-size"
      value = "1024m"
    },
    {
      name  = "ingress.annotations.nginx\\.ingress\\.kubernetes\\.io/proxy-connect-timeout"
      value = "30"
      type  = "string"
    },
    {
      name  = "ingress.annotations.nginx\\.ingress\\.kubernetes\\.io/proxy-read-timeout"
      value = "1800"
      type  = "string"
    },

    {
      name  = "ingress.annotations.nginx\\.ingress\\.kubernetes\\.io/proxy-send-timeout"
      value = "1800"
      type  = "string"
    },

    {
      name  = "ingress.ingressClassName"
      value = "nginx"
    },
    {
      name  = "ingress.annotations.use-proxy-protocol"
      value = "true"
      type  = "string"
    },

    {
      name  = "hub.config.Authenticator.auth_login"
      value = true
    },

    {
      name  = "hub.config.GitHubOAuthenticator.client_id"
      value = var.client_id
    },

    {
      name  = "hub.config.GitHubOAuthenticator.admin_users"
      value = join(",", var.gh_admin_users)
    },
    {
      name  = "hub.config.GitHubOAuthenticator.oauth_callback_url"
      value = "https://${var.hostname}/hub/oauth_callback"
    },

    {
      name  = "hub.config.JupyterHub.authenticator_class"
      value = "github"
    },
    {
      name  = "hub.db.pvc.storageClassName"
      value = "linode-block-storage-retain"
    },
    {
      name  = "hub.db.pvc.volumeName"
      value = var.hub_db_volume
    },
    {
      name  = "hub.config.JupyterHub.admin_access"
      value = false
    }
  ]
}
