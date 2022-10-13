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

  set {
    name  = "ingress.enabled"
    value = true
  }
  set {
    name  = "ingress.hosts"
    value = "{${join(",", [var.hostname])}}"
  }

  set {
    name  = "hub.config.GitHubOAuthenticator.client_id"
    value = var.client_id
  }
  set {
    name  = "hub.config.GitHubOAuthenticator.client_secret"
    value = var.client_secret
  }
  set {
    name  = "hub.config.GitHubOAuthenticator.oauth_callback_url"
    value = "https://{var.hostname}/hub/oauth_callback"
  }
  set {
    name  = "hub.config.JupyterHub.authenticator_class"
    value = "github"
  }
}
