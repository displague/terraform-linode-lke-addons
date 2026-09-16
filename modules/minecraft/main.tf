resource "kubernetes_namespace" "minecraft" {
  metadata {
    name = var.namespace
  }
}

# Terraform-managed PVC for the minecraft datadir. Owning the PVC out here
# (rather than letting the itzg chart mint one via `persistence.dataDir` alone)
# means a `helm uninstall` — or the `terraform` provider destroying the release
# — doesn't leave the PV `Released` and cause a new PV to be provisioned on the
# next apply. See README.md for the migration story if you have an existing
# chart-managed PVC.
resource "kubernetes_persistent_volume_claim" "datadir" {
  metadata {
    name      = var.claim
    namespace = kubernetes_namespace.minecraft.metadata[0].name
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/name"       = "minecraft"
      "app.kubernetes.io/component"  = "datadir"
    }
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = var.storage_class
    resources {
      requests = {
        storage = var.storage_size
      }
    }
    # When rebinding an existing Retain PV (post-outage recovery or moving a
    # world between environments), set var.volume_name so the PVC lands on the
    # exact PV. Leave "" for dynamic provisioning.
    volume_name = var.volume_name != "" ? var.volume_name : null
  }

  # Don't block terraform apply on a Retain PV that hasn't been re-associated
  # yet — the pod will wait once it's bound.
  wait_until_bound = false
}

resource "helm_release" "minecraft" {
  name       = "minecraft"
  repository = "https://itzg.github.io/minecraft-server-charts/"
  chart      = "minecraft"
  version    = var.chart_version
  namespace  = kubernetes_namespace.minecraft.metadata[0].name

  values = [jsonencode({
    minecraftServer = {
      serviceType = var.service_type
      version     = var.mc_version
      ops         = var.ops
      motd        = var.motd
      pvp         = true
      servicePort = var.port
      jvmXXOpts   = "-XX:+UnlockExperimentalVMOptions -XX:G1NewSizePercent=20 -XX:G1ReservePercent=20 -XX:MaxGCPauseMillis=50 -XX:G1HeapRegionSize=32M"
    }
    # Only annotate the Service for external-dns when we're the ones owning
    # the public DNS name (i.e. the LoadBalancer case). When routed via
    # mc-router, the router's own LB Service owns the DNS records.
    serviceAnnotations = var.service_type == "LoadBalancer" ? {
      "external-dns.alpha.kubernetes.io/hostname" = var.hostname
      "external-dns.alpha.kubernetes.io/ttl"      = "180"
    } : {}
  })]

  set = [
    {
      name  = "minecraftServer.eula"
      value = "TRUE"
    },
    {
      name  = "persistence.dataDir.enabled"
      value = true
    },
    # Tie the chart's `existingClaim` to the terraform-managed PVC's name so
    # helm never provisions its own PVC. storageClass/size stay set here for
    # completeness but the chart won't act on them when `existingClaim` is set.
    {
      name  = "persistence.dataDir.storageClass"
      value = var.storage_class
    },
    {
      name  = "persistence.dataDir.Size"
      value = var.storage_size
    },
    {
      name  = "persistence.dataDir.existingClaim"
      value = kubernetes_persistent_volume_claim.datadir.metadata[0].name
    }
  ]

  depends_on = [kubernetes_persistent_volume_claim.datadir]
}
