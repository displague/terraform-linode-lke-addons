# Envoy Gateway (Gateway API) — the cluster's single entrypoint.
#
# One Gateway with:
#   - http/80        → redirect to https
#   - https/443      → one listener per hostname in var.http_routes, TLS
#                      terminated at Envoy with a cert-manager cert
#   - tcp/<tcp_port> → raw TCP passthrough for var.tcp_routes (Minecraft)
#
# One Gateway == one Envoy Deployment == one LoadBalancer Service == one
# Linode NodeBalancer. That is the whole point: ingress-nginx + a separate
# mc-router LoadBalancer cost two NBs; this costs one.
#
# No PROXY protocol. A Linode NodeBalancer is an L4 proxy, so client IPs
# are only recoverable via PROXY protocol, and PROXY protocol is exactly what
# forces the hairpin-proxy workaround (in-cluster clients that resolve a
# public hostname get short-circuited by kube-proxy straight to the pod,
# skipping the NB that would have added the PROXY header). Nothing here
# needs client IPs, so we drop both.

resource "helm_release" "envoy_gateway" {
  name             = "envoy-gateway"
  repository       = "oci://docker.io/envoyproxy"
  chart            = "gateway-helm"
  version          = var.chart_version
  namespace        = "envoy-gateway-system"
  create_namespace = true
  # The chart installs Gateway API CRDs (experimental channel) + its own.
  # Helm won't upgrade CRDs in-place later; see README for the bump recipe.
}

resource "kubernetes_namespace" "gateway" {
  metadata { name = var.namespace }
}

locals {
  gw_ns = kubernetes_namespace.gateway.metadata[0].name

  # Listener names must be DNS-label-ish and unique; derive from hostname.
  https_listeners = {
    for r in var.http_routes : r.hostname => {
      name   = "https-${replace(r.hostname, ".", "-")}"
      secret = "${r.hostname}-tls"
    }
  }

  service_annotations = merge(
    {
      # Disposable NB: external-dns keeps DNS in sync, certs live in-cluster.
      "service.beta.kubernetes.io/linode-loadbalancer-preserve" = "false"
    },
    var.ipv6_ingress ? {
      "service.beta.kubernetes.io/linode-loadbalancer-enable-ipv6-ingress" = "true"
    } : {},
  )
}

resource "kubectl_manifest" "gatewayclass" {
  depends_on        = [helm_release.envoy_gateway]
  server_side_apply = true
  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "GatewayClass"
    metadata   = { name = "eg" }
    spec       = { controllerName = "gateway.envoyproxy.io/gatewayclass-controller" }
  })
}

# Data-plane customisation: annotations on the generated LoadBalancer Service.
resource "kubectl_manifest" "envoyproxy" {
  depends_on        = [helm_release.envoy_gateway]
  server_side_apply = true
  yaml_body = yamlencode({
    apiVersion = "gateway.envoyproxy.io/v1alpha1"
    kind       = "EnvoyProxy"
    metadata   = { name = var.gateway_name, namespace = local.gw_ns }
    spec = {
      provider = {
        type = "Kubernetes"
        kubernetes = {
          envoyService = {
            type                  = "LoadBalancer"
            externalTrafficPolicy = var.external_traffic_policy
            annotations           = local.service_annotations
          }
          envoyDeployment = {
            replicas = var.replicas
            pod = {
              # Spread replicas across nodes when possible; don't block
              # scheduling when the pool is a single node.
              affinity = {
                podAntiAffinity = {
                  preferredDuringSchedulingIgnoredDuringExecution = [{
                    weight = 100
                    podAffinityTerm = {
                      topologyKey = "kubernetes.io/hostname"
                      labelSelector = {
                        matchLabels = { "gateway.envoyproxy.io/owning-gateway-name" = var.gateway_name }
                      }
                    }
                  }]
                }
              }
            }
          }
        }
      }
    }
  })
}

resource "kubectl_manifest" "gateway" {
  depends_on        = [kubectl_manifest.gatewayclass, kubectl_manifest.envoyproxy]
  server_side_apply = true
  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "Gateway"
    metadata = {
      name      = var.gateway_name
      namespace = local.gw_ns
      annotations = {
        # cert-manager gateway-shim: one Certificate per HTTPS listener,
        # written to that listener's certificateRefs secret.
        "cert-manager.io/cluster-issuer" = var.cluster_issuer
      }
    }
    spec = {
      gatewayClassName = "eg"
      infrastructure = {
        parametersRef = {
          group = "gateway.envoyproxy.io"
          kind  = "EnvoyProxy"
          name  = var.gateway_name
        }
      }
      listeners = concat(
        [{
          name          = "http"
          protocol      = "HTTP"
          port          = 80
          allowedRoutes = { namespaces = { from = "All" } }
        }],
        [for host, l in local.https_listeners : {
          name          = l.name
          protocol      = "HTTPS"
          port          = 443
          hostname      = host
          allowedRoutes = { namespaces = { from = "All" } }
          tls = {
            mode            = "Terminate"
            certificateRefs = [{ kind = "Secret", name = l.secret }]
          }
        }],
        length(var.tcp_routes) == 0 ? [] : [{
          name     = "tcp"
          protocol = "TCP"
          port     = var.tcp_port
          allowedRoutes = {
            namespaces = { from = "All" }
            kinds      = [{ kind = "TCPRoute" }]
          }
        }],
      )
    }
  })
}

# http/80 → https redirect for everything.
resource "kubectl_manifest" "http_redirect" {
  depends_on        = [kubectl_manifest.gateway]
  server_side_apply = true
  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata   = { name = "${var.gateway_name}-https-redirect", namespace = local.gw_ns }
    spec = {
      parentRefs = [{ name = var.gateway_name, sectionName = "http" }]
      rules = [{
        filters = [{
          type            = "RequestRedirect"
          requestRedirect = { scheme = "https", statusCode = 301 }
        }]
      }]
    }
  })
}

resource "kubectl_manifest" "http_route" {
  for_each          = { for r in var.http_routes : r.hostname => r }
  depends_on        = [kubectl_manifest.gateway]
  server_side_apply = true
  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata   = { name = replace(each.key, ".", "-"), namespace = each.value.namespace }
    spec = {
      parentRefs = [{
        name        = var.gateway_name
        namespace   = local.gw_ns
        sectionName = local.https_listeners[each.key].name
      }]
      hostnames = [each.key]
      rules = [{
        backendRefs = [{ name = each.value.service, port = each.value.port }]
        timeouts    = { request = each.value.request_timeout }
      }]
    }
  })
}

resource "kubectl_manifest" "tcp_route" {
  for_each          = { for r in var.tcp_routes : "${r.namespace}-${r.service}" => r }
  depends_on        = [kubectl_manifest.gateway]
  server_side_apply = true
  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1alpha2"
    kind       = "TCPRoute"
    metadata = {
      name      = each.value.service
      namespace = each.value.namespace
      annotations = {
        # TCPRoute has no hostnames field; external-dns's gateway-tcproute
        # source reads them from this annotation and publishes them against
        # the Gateway's address.
        "external-dns.alpha.kubernetes.io/hostname" = join(",", each.value.hostnames)
      }
    }
    spec = {
      parentRefs = [{ name = var.gateway_name, namespace = local.gw_ns, sectionName = "tcp" }]
      rules      = [{ backendRefs = [{ name = each.value.service, port = each.value.port }] }]
    }
  })
}

# Optional smoke-test app (traefik/whoami echoes the request it received).
resource "kubectl_manifest" "example_deployment" {
  count             = var.example_host != "" ? 1 : 0
  server_side_apply = true
  yaml_body = yamlencode({
    apiVersion = "apps/v1"
    kind       = "Deployment"
    metadata   = { name = "example", namespace = local.gw_ns, labels = { app = "example" } }
    spec = {
      replicas = 1
      selector = { matchLabels = { app = "example" } }
      template = {
        metadata = { labels = { app = "example" } }
        spec = {
          containers = [{
            name  = "whoami"
            image = "traefik/whoami:v1.11.0"
            ports = [{ containerPort = 80, name = "http" }]
          }]
        }
      }
    }
  })
}

resource "kubectl_manifest" "example_service" {
  count             = var.example_host != "" ? 1 : 0
  server_side_apply = true
  yaml_body = yamlencode({
    apiVersion = "v1"
    kind       = "Service"
    metadata   = { name = "example", namespace = local.gw_ns }
    spec = {
      selector = { app = "example" }
      ports    = [{ name = "http", port = 80, targetPort = "http" }]
    }
  })
}
