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
    serviceAnnotations = merge(var.service_type == "LoadBalancer" ? {
      "external-dns.alpha.kubernetes.io/hostname" = var.hostname
      "external-dns.alpha.kubernetes.io/ttl"      = "180"
      } : {}, var.mc_router_discovery ? merge({
        # mc-router (with autoscale) finds its routes from Service
        # annotations instead of a static MAPPING.
        "mc-router.itzg.me/externalServerName" = var.hostname
        }, var.scale_to_zero ? {} : {
        # Still a Deployment: route only, never scale. mc-router keys its
        # StatefulSet lookup by Service name alone (not namespace), so once
        # another namespace has a StatefulSet "minecraft" it would try to
        # scale one here, fail, and drop the join.
        "mc-router.itzg.me/autoScaleUp"   = "false"
        "mc-router.itzg.me/autoScaleDown" = "false"
    }) : {})
    # mc-router can only scale StatefulSets. The pod keeps mounting the
    # module's PVC (existingClaim below), so no volumeClaimTemplate and no
    # new volume. `Recreate` is Deployment-only; a 1-replica StatefulSet
    # rolls delete-then-create under RollingUpdate. A helm upgrade puts
    # replicas back to 1; mc-router scales it down again when idle.
    # (Set unconditionally: a `cond ? {...} : {}` here would turn the bool
    # into the string "true", which the chart's ternary rejects.)
    workloadAsStatefulSet = var.scale_to_zero
    strategyType          = var.scale_to_zero ? "RollingUpdate" : "Recreate"
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
