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

locals {
  # mc-router (1.49.0) starts a server's idle timer only when it first creates
  # the route, when the backend comes up, or when a connection closes.
  # Switching an existing server to scale_to_zero updates its route in place,
  # so no timer starts and the server never sleeps. Hashing the sorted
  # scale-to-zero namespaces into a pod annotation rolls the router whenever
  # that set changes. The new pod creates every route afresh and starts the
  # timers. Applies that leave the set alone leave the router alone.
  scale_to_zero_checksum = sha256(jsonencode(sort(distinct(var.autoscale.namespaces))))
}

resource "helm_release" "mc_router" {
  name             = "mc-router"
  repository       = "https://itzg.github.io/minecraft-server-charts/"
  chart            = "mc-router"
  version          = var.chart_version
  namespace        = var.namespace
  create_namespace = true

  values = [jsonencode(merge(length(var.image_pull_secrets) > 0 ? {
    imagePullSecrets = [for s in var.image_pull_secrets : { name = s }]
    } : {}, {
    services = {
      minecraft = {
        type = var.service_type
        port = var.external_port
        # Only meaningful on a LoadBalancer Service; behind a Gateway the
        # TCPRoute carries the external-dns hostnames instead.
        annotations = var.service_type != "LoadBalancer" ? {} : merge({
          # Publish every backing hostname as a DNS record pointing at this
          # single NodeBalancer via external-dns.
          "external-dns.alpha.kubernetes.io/hostname" = join(",", [for m in var.mappings : m.hostname])
          "external-dns.alpha.kubernetes.io/ttl"      = "180"
          # This NB is disposable — external-dns keeps DNS in sync and no
          # cert is bound to the IP. Explicit `false` (ccm-linode's default)
          # so a future default flip can't leave a stale $10/mo NB behind.
          "service.beta.kubernetes.io/linode-loadbalancer-preserve" = "false"
          }, var.proxy_protocol == "on" ? {
          # The NB prepends PROXY v2; mc-router (RECEIVE_PROXY_PROTOCOL below)
          # strips it. Only safe with a node firewall: see modules/cloud_firewall.
          "service.beta.kubernetes.io/linode-loadbalancer-default-proxy-protocol" = "v2"
        } : {})
      }
    }
    # Meets the restricted Pod Security Standard (#79). The image already runs
    # as UID 65532 and needs no capabilities: both ports are above 1024 and it
    # writes nothing to disk.
    podSecurityContext = {
      runAsNonRoot   = true
      runAsUser      = 65532
      runAsGroup     = 65532
      seccompProfile = { type = "RuntimeDefault" }
    }
    securityContext = {
      allowPrivilegeEscalation = false
      readOnlyRootFilesystem   = true
      capabilities             = { drop = ["ALL"] }
    }
    # Only with autoscale, so a router without it never rolls for this. The
    # release depends on the scaler RoleBindings, so the new pod starts with
    # the permissions for a newly added namespace.
    podAnnotations = var.autoscale.enabled ? {
      "lke-addons/scale-to-zero-checksum" = local.scale_to_zero_checksum
    } : {}
    image = {
      tag = var.image_tag
      # A pinned tag doesn't need re-pulling on every restart.
      pullPolicy = "IfNotPresent"
    }
    minecraftRouter = merge({
      # With autoscale, routes come from Service annotations (see rbac.tf and
      # modules/minecraft `mc_router_discovery`): a static mapping has no
      # StatefulSet to wake.
      mappings = var.autoscale.enabled ? [] : [
        for m in var.mappings : {
          externalHostname = m.hostname
          host             = split(":", m.target)[0]
          port             = tonumber(split(":", m.target)[1])
        }
      ]
      }, var.autoscale.enabled ? {
      # null rather than true: true makes the chart's own ClusterRole grant
      # update/patch on every StatefulSet in the cluster, and false still
      # renders AUTO_SCALE_UP=false. null (Helm drops the key) renders
      # neither; extraEnv below turns autoscale on and rbac.tf grants only
      # what it needs. (The chart's schema rejects "".)
      autoScale = {
        up   = { enabled = null }
        down = { enabled = null }
      }
    } : {})
    extraEnv = merge(
      # The header is optional (mc-router's listener policy is USE), so
      # connections that skip the NodeBalancer / Envoy keep working without it.
      var.proxy_protocol == "off" ? {} : { RECEIVE_PROXY_PROTOCOL = "true" },
      var.proxy_protocol == "off" || length(var.trusted_proxies) == 0 ? {} : { TRUSTED_PROXIES = join(",", var.trusted_proxies) },
      var.autoscale.enabled ? {
        AUTO_SCALE_UP         = "true"
        AUTO_SCALE_DOWN       = "true"
        AUTO_SCALE_DOWN_AFTER = var.autoscale.down_after
        # Asleep: the server list shows this instead of timing out. A join
        # wakes the server, but volume attach + JVM start outlasts the Java
        # client's 30 s connect timeout: the first join times out, the next works.
        AUTO_SCALE_ASLEEP_MOTD  = var.autoscale.asleep_motd
        AUTO_SCALE_LOADING_MOTD = var.autoscale.loading_motd
      } : {},
    )
  }))]

  # The Roles exist before the router starts scaling.
  depends_on = [kubernetes_cluster_role_binding_v1.statefulset_reader, kubernetes_role_binding_v1.scaler]
}
