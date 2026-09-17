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

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.6 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 3.0.0 |
| <a name="requirement_kubectl"></a> [kubectl](#requirement\_kubectl) | >= 1.19.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.38.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_helm"></a> [helm](#provider\_helm) | >= 3.0.0 |
| <a name="provider_kubectl"></a> [kubectl](#provider\_kubectl) | >= 1.19.0 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | >= 2.38.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [helm_release.envoy_gateway](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubectl_manifest.envoyproxy](https://registry.terraform.io/providers/gavinbunney/kubectl/latest/docs/resources/manifest) | resource |
| [kubectl_manifest.example_deployment](https://registry.terraform.io/providers/gavinbunney/kubectl/latest/docs/resources/manifest) | resource |
| [kubectl_manifest.example_service](https://registry.terraform.io/providers/gavinbunney/kubectl/latest/docs/resources/manifest) | resource |
| [kubectl_manifest.gateway](https://registry.terraform.io/providers/gavinbunney/kubectl/latest/docs/resources/manifest) | resource |
| [kubectl_manifest.gatewayclass](https://registry.terraform.io/providers/gavinbunney/kubectl/latest/docs/resources/manifest) | resource |
| [kubectl_manifest.http_redirect](https://registry.terraform.io/providers/gavinbunney/kubectl/latest/docs/resources/manifest) | resource |
| [kubectl_manifest.http_route](https://registry.terraform.io/providers/gavinbunney/kubectl/latest/docs/resources/manifest) | resource |
| [kubectl_manifest.tcp_route](https://registry.terraform.io/providers/gavinbunney/kubectl/latest/docs/resources/manifest) | resource |
| [kubernetes_namespace.gateway](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_chart_version"></a> [chart\_version](#input\_chart\_version) | envoyproxy/gateway-helm chart version. Ships the Gateway API CRDs (experimental channel, so TCPRoute is included). Bump deliberately: CRD upgrades are manual with helm. | `string` | `"v1.9.1"` | no |
| <a name="input_cluster_issuer"></a> [cluster\_issuer](#input\_cluster\_issuer) | cert-manager ClusterIssuer used (via the gateway-shim annotation) to issue a certificate per HTTPS listener. | `string` | `"letsencrypt-prod"` | no |
| <a name="input_example_host"></a> [example\_host](#input\_example\_host) | If set, deploy a tiny `whoami` app in the module namespace and expose it at this hostname. Handy smoke test: it echoes the request headers it received. | `string` | `""` | no |
| <a name="input_gateway_name"></a> [gateway\_name](#input\_gateway\_name) | Name of the single Gateway this module manages. One Gateway == one Envoy Deployment == one LoadBalancer Service == one Linode NodeBalancer. | `string` | `"main"` | no |
| <a name="input_http_routes"></a> [http\_routes](#input\_http\_routes) | HTTP(S) hosts to expose. For each entry the module creates an HTTPS<br>listener on 443 with `hostname`, a cert-manager-issued certificate, and<br>an HTTPRoute in `namespace` forwarding to `service:port`. Plain HTTP on 80<br>is redirected to HTTPS for every host. `request_timeout` is the Gateway<br>API HTTPRoute `timeouts.request`; the default `0s` disables it (websocket<br>/ long-poll friendly, matches the old 1800s nginx read timeout in<br>practice). | <pre>list(object({<br>    hostname        = string<br>    namespace       = string<br>    service         = string<br>    port            = number<br>    request_timeout = optional(string, "0s")<br>  }))</pre> | `[]` | no |
| <a name="input_ipv6_ingress"></a> [ipv6\_ingress](#input\_ipv6\_ingress) | Ask ccm-linode to publish the NodeBalancer's IPv6 address too (`linode-loadbalancer-enable-ipv6-ingress`). Frontend only; no dual-stack cluster required. external-dns then publishes AAAA records alongside A. | `bool` | `true` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Namespace that holds the Gateway, its EnvoyProxy config, the issued TLS secrets and the optional example app. (Envoy Gateway's own controller lives in `envoy-gateway-system`.) | `string` | `"gateway"` | no |
| <a name="input_tcp_port"></a> [tcp\_port](#input\_tcp\_port) | External port of the TCP listener used by `tcp_routes`. | `number` | `25565` | no |
| <a name="input_tcp_routes"></a> [tcp\_routes](#input\_tcp\_routes) | Raw TCP backends exposed on `tcp_port` (a single TCP listener; the<br>backend does its own demux, e.g. mc-router routing Minecraft by handshake<br>hostname). Each entry becomes a TCPRoute in `namespace` with the given<br>hostnames published by external-dns against the Gateway address. | <pre>list(object({<br>    hostnames = list(string) # DNS names external-dns should publish for this listener<br>    namespace = string<br>    service   = string<br>    port      = number<br>  }))</pre> | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_gateway_name"></a> [gateway\_name](#output\_gateway\_name) | Name of the Gateway resource. |
| <a name="output_namespace"></a> [namespace](#output\_namespace) | Namespace holding the Gateway. |
<!-- END_TF_DOCS -->