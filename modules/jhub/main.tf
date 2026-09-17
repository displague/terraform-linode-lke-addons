resource "kubernetes_namespace" "jupyterhub" {
  metadata { name = "jupyterhub" }
}

# Terraform-managed PVC for JupyterHub's sqlite database, in the same spirit
# as `modules/minecraft`'s `datadir` PVC. The chart's built-in `sqlite-pvc`
# mode was locking us into an immutable-field trap whenever the upstream
# `values.schema.json` dropped a field like `volumeName` — helm would try
# to reconcile the running PVC and k8s would reject the change on
# `spec.volumeName` (immutable after binding).
#
# By flipping the chart to `hub.db.type = "other"` and mounting our own
# PVC via `hub.extraVolumes` / `hub.extraVolumeMounts` at the same
# `/srv/jupyterhub` path the chart used, helm no longer manages the PVC —
# terraform does. Same underlying block volume, same on-disk sqlite file.
resource "kubernetes_persistent_volume_claim" "hub_db" {
  metadata {
    name      = var.hub_db_claim
    namespace = kubernetes_namespace.jupyterhub.metadata[0].name
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/name"       = "jupyterhub"
      "app.kubernetes.io/component"  = "hub-db"
    }
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = var.hub_db_storage_class
    resources {
      requests = {
        storage = var.hub_db_storage_size
      }
    }
    # When rebinding an existing Retain PV (post-outage recovery or
    # migrating from the chart-managed PVC), set var.hub_db_volume so the
    # PVC lands on that specific PV. Leave "" for dynamic provisioning.
    volume_name = var.hub_db_volume != "" ? var.hub_db_volume : null
  }

  wait_until_bound = false
}

# https://artifacthub.io/packages/helm/bitnami/external-dns
resource "helm_release" "jupyterhub" {
  name              = "jupyterhub"
  repository        = "https://jupyterhub.github.io/helm-chart/"
  chart             = "jupyterhub"
  namespace         = kubernetes_namespace.jupyterhub.metadata[0].name
  force_update      = true
  dependency_update = true

  # `hub.db.type = "other"` disables the chart's built-in PVC template.
  # We mount our terraform-managed PVC at the same `/srv/jupyterhub` path
  # the chart used in `sqlite-pvc` mode, and point `hub.db.url` at the
  # same sqlite file the chart would have created there. Migration is
  # therefore transparent to a running hub — same file at the same path.
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
    hub:
      db:
        type: other
        url: sqlite:////srv/jupyterhub/jupyterhub.sqlite
      extraVolumes:
        - name: hub-db
          persistentVolumeClaim:
            claimName: ${kubernetes_persistent_volume_claim.hub_db.metadata[0].name}
      extraVolumeMounts:
        - name: hub-db
          mountPath: /srv/jupyterhub
  EOT
  ]

  set_sensitive = [{
    name  = "hub.config.GitHubOAuthenticator.client_secret"
    value = var.client_secret
  }]

  set = [
    {
      name  = "proxy.service.type"
      value = var.proxy_service_type
    },
    {
      name  = "ingress.annotations.cert-manager\\.io/cluster-issuer"
      value = "letsencrypt-prod"
    },

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
      name  = "hub.config.JupyterHub.admin_access"
      value = false
    }
  ]

  depends_on = [kubernetes_persistent_volume_claim.hub_db]
}
