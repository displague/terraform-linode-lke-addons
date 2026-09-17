## Gateway module (Envoy Gateway, Gateway API)

The cluster's single entrypoint: one `Gateway` → one Envoy Deployment → one
LoadBalancer Service → **one Linode NodeBalancer**. Replaces ingress-nginx
(unmaintained since March 2026) and the separate mc-router LoadBalancer.

Listeners on the one Gateway:

- `http/80` — redirects everything to HTTPS.
- `https/443` — one listener per hostname in `http_routes`; TLS terminated at
  Envoy with a certificate cert-manager issues via the gateway-shim
  (`cert-manager.io/cluster-issuer` annotation on the Gateway). DNS-01 is
  unaffected by the ingress layer.
- `tcp/<tcp_port>` — raw TCP for `tcp_routes` (Minecraft via mc-router, which
  demuxes by handshake hostname).

No PROXY protocol on purpose: a NodeBalancer is an L4 proxy, so client IPs
would need PROXY protocol, and PROXY protocol is what forced the old
`hairpin-proxy` workaround. Nothing here needs client IPs.

### Inputs (root-level)

```hcl
gateway_enabled       = true
gateway_ipv6_ingress  = true   # AAAA on the NB too, no dual-stack needed
extra_http_routes = [
  { hostname = "app.example.com", namespace = "app", service = "app", port = 80 },
]
```

### Cutover (from ingress-nginx)

1. `gateway_enabled = true`, then `terraform apply -target=module.gateway`.
   Envoy Gateway, the Gateway, routes and certificates come up next to
   nginx. DNS is untouched. Verify with `curl --resolve host:443:<gw-ip>`.
2. `terraform apply` (no target). cert-manager's gateway-shim turns on,
   external-dns switches to the `gateway-httproute` / `gateway-tcproute`
   sources and re-points every host at the Gateway's NB, mc-router becomes
   ClusterIP behind the TCPRoute, the nginx Ingresses for jhub/triage are
   removed. Clients with cached DNS see a blip up to the TTL (180 s).
3. (historical) ingress-nginx and hairpin-proxy were removed from this
   module set once the Gateway owned DNS; their NodeBalancer was reaped
   (`preserve=false`). If you migrated from a fork that still has them,
   uninstall them and delete any orphaned NodeBalancer by hand (ccm-linode
   doesn't reap on Service type change).

### Upgrading Envoy Gateway

Helm won't upgrade CRDs in place. Before bumping `chart_version`, apply the
new release's CRDs manually (see the Envoy Gateway release notes), then
`terraform apply`.
