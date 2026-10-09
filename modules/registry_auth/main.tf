# Docker Hub pull credentials for namespaces whose pods pull from Docker Hub.
#
# Anonymous Docker Hub pulls are rate-limited per source IP, and images on
# `:latest` with `imagePullPolicy: Always` pull on every restart. Kubernetes
# has no cluster-wide pull secret (and LKE doesn't expose kubelet config), so
# each namespace gets a dockerconfigjson Secret, attached to its `default`
# ServiceAccount. Charts that run pods under their own ServiceAccount take the
# Secret name through their own `imagePullSecrets` value instead.

locals {
  auth = base64encode("${var.username}:${var.token}")
}

resource "kubernetes_secret_v1" "dockerhub" {
  for_each = toset(var.namespaces)

  metadata {
    name      = var.secret_name
    namespace = each.value
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        "https://index.docker.io/v1/" = {
          username = var.username
          password = var.token
          auth     = local.auth
        }
      }
    })
  }
}

resource "kubernetes_default_service_account_v1" "default" {
  for_each = toset(var.default_service_account_namespaces)

  metadata {
    namespace = each.value
  }

  image_pull_secret {
    name = kubernetes_secret_v1.dockerhub[each.value].metadata[0].name
  }
}
