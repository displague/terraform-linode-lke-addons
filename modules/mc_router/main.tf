# itzg/mc-router — one LoadBalancer NodeBalancer that fronts multiple
# minecraft servers on port 25565, routing by the hostname the client dialed
# (Minecraft's handshake carries the server address the client used).
#
# Consolidates N per-server LoadBalancers (each = one Linode NodeBalancer =
# ~$10/mo) down to a single one.
#
# NOTE: this module deliberately does NOT try to share an existing
# NodeBalancer (e.g. ingress-nginx's) via ccm-linode's `nodebalancer-id`
# annotation. That annotation is single-Service *adopt*, not multi-Service
# share: each LoadBalancer Service's reconciler rewrites the NB's entire
# port-config list to match only its own ports, so two Services on one NB
# stomp each other (ingress lost 80/443 when this was tried). One
# LoadBalancer Service == one NodeBalancer. To get to a single NB, expose
# 25565 on the ingress-nginx Service instead (its `tcp-services`
# ConfigMap) and run mc-router as ClusterIP — see the module README.

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
        type = var.service_type
        port = var.external_port
        # Only meaningful on a LoadBalancer Service; behind a Gateway the
        # TCPRoute carries the external-dns hostnames instead.
        annotations = var.service_type != "LoadBalancer" ? {} : {
          # Publish every backing hostname as a DNS record pointing at this
          # single NodeBalancer via external-dns.
          "external-dns.alpha.kubernetes.io/hostname" = join(",", [for m in var.mappings : m.hostname])
          "external-dns.alpha.kubernetes.io/ttl"      = "180"
          # This NB is disposable — external-dns keeps DNS in sync and no
          # cert is bound to the IP. Explicit `false` (ccm-linode's default)
          # so a future default flip can't leave a stale $10/mo NB behind.
          "service.beta.kubernetes.io/linode-loadbalancer-preserve" = "false"
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
