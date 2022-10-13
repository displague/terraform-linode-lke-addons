resource "helm_release" "minecraft" {
  name             = "minecraft"
  repository       = "https://itzg.github.io/minecraft-server-charts/"
  chart            = "minecraft"
  namespace        = "minecraft"
  create_namespace = true

  set {
    name = "minecraftServer.eula"
    value = "TRUE"
  }

  values = [jsonencode({
    minecraftServer = {
      serviceType = "LoadBalancer"
      ops = var.ops
      motd = var.motd
      pvp = true
      jvmXXOpts = "-XX:+UnlockExperimentalVMOptions -XX:G1NewSizePercent=20 -XX:G1ReservePercent=20 -XX:MaxGCPauseMillis=50 -XX:G1HeapRegionSize=32M"
    }
    serviceAnnotations = {
      "external-dns.alpha.kubernetes.io/hostname" = var.hostname
      "external-dns.alpha.kubernetes.io/ttl" = "180"
    }
    initContainers = [{
      name = "fix-perms"
      securityContext = {
        privileged = false
        readOnlyRootFilesystem = false
        runAsUser = 0
      }
      image = "busybox"
      command = ["sh", "-c", "chown -R 1000:1000 /data; sleep 30"]
      volumeMounts = [{
         name = "datadir"
         mountPath = "/data"
      }]
    }]
  })]

  set {
    name = "persistence.dataDir.storageClass"
    # value = "linode-block-storage-retain"
    value = "longhorn"
  }
  set {
    name = "persistence.dataDir.enabled"
    value = true
  }
  set {
    name = "persistence.dataDir.Size"
    value = "10Gi"
  }
}
