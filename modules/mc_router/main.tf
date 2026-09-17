# itzg/mc-router — one LoadBalancer NodeBalancer that fronts multiple
# minecraft servers on port 25565, routing by the hostname the client dialed
# (Minecraft's handshake carries the server address the client used).
#
# Consolidates N per-server LoadBalancers (each = one Linode NodeBalancer =
# ~$10/mo) down to a single one — and with `share_nodebalancer_id`, can
# further piggyback onto an *existing* NodeBalancer (e.g. ingress-nginx's)
# so the cluster ends up with a single Linode NodeBalancer total.

locals {
  # `preserve` says "don't delete the underlying NB if the Service is
  # deleted". Two cases:
  #  - We own our NB (share_nodebalancer_id == null): the NB is disposable
  #    (external-dns keeps DNS in sync, no cert is bound to the IP).
  #    Explicit `false` to defend against a future default flip.
  #  - We share someone else's NB: MUST NOT delete it on Service delete,
  #    since it belongs to the other Service (ingress-nginx typically) and
  #    that Service didn't ask for its NB to be reaped.
  preserve_value = var.share_nodebalancer_id == null ? "false" : "true"

  share_annotations = var.share_nodebalancer_id == null ? {} : {
    "service.beta.kubernetes.io/linode-loadbalancer-nodebalancer-id" = tostring(var.share_nodebalancer_id)
  }
}

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
        # single NodeBalancer via external-dns. Merged with the optional
        # NB-share annotations so both drive the same Service.
        annotations = merge(
          {
            "external-dns.alpha.kubernetes.io/hostname"              = join(",", [for m in var.mappings : m.hostname])
            "external-dns.alpha.kubernetes.io/ttl"                   = "180"
            "service.beta.kubernetes.io/linode-loadbalancer-preserve" = local.preserve_value
          },
          local.share_annotations,
        )
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
