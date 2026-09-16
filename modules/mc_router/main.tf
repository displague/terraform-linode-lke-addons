# itzg/mc-router — one LoadBalancer NodeBalancer that fronts multiple
# minecraft servers on port 25565, routing by the hostname the client dialed
# (Minecraft's handshake carries the server address the client used).
#
# Consolidates N per-server LoadBalancers (each = one Linode NodeBalancer =
# ~$10/mo) down to a single one.

resource "helm_release" "mc_router" {
  name             = "mc-router"
  repository       = "https://itzg.github.io/minecraft-server-charts/"
  chart            = "mc-router"
  version          = var.chart_version
  namespace        = var.namespace
  create_namespace = true

  values = [jsonencode({
    services = {
      minecraft = {
        type = "LoadBalancer"
        port = var.external_port
        # Publish every backing hostname as a DNS record pointing at this
        # single NodeBalancer via external-dns.
        annotations = {
          "external-dns.alpha.kubernetes.io/hostname" = join(",", [for m in var.mappings : m.hostname])
          "external-dns.alpha.kubernetes.io/ttl"      = "180"
        }
      }
    }
    minecraftRouter = {
      mappings = [
        for m in var.mappings : {
          externalHostname = m.hostname
          host             = split(":", m.target)[0]
          port             = tonumber(split(":", m.target)[1])
        }
      ]
    }
  })]
}
