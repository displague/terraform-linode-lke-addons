## mc-router module

Wraps [`itzg/mc-router`](https://github.com/itzg/mc-router) as a single-LoadBalancer,
handshake-hostname-routing frontend for multiple minecraft servers. On Linode,
each `type: LoadBalancer` Service turns into a dedicated NodeBalancer (~$10/mo),
so running several minecraft servers each with their own LB is proportionally
expensive. mc-router lets you keep the "each server has its own DNS name on the
default 25565" UX while paying for exactly one NodeBalancer.

### Inputs

| Name | Description |
|------|-------------|
| `mappings` | list of `{ hostname, target }` — the external hostname a Minecraft client dials, and the in-cluster Service address:port to route it to. |
| `external_port` | port exposed by the mc-router LoadBalancer (default `25565`). |
| `namespace` / `chart_version` | boring knobs. |

### Cutover recipe

Assumes you're moving from three per-server LoadBalancers on `mc1.example.com`,
`mc2.example.com`, `mc3.example.com` to a single mc-router.

1. **Deploy mc-router first** with mappings pointing at your existing minecraft
   Services. Because the mappings' targets are Service names (not the current
   NodeBalancer IPs), traffic paths are unaffected while both sets exist.
2. **Wait for external-dns** to publish the new A records for each hostname
   against mc-router's NodeBalancer IP. `kubectl -n external-dns logs` shows
   the CREATE/UPSERT events; DNS propagation takes up to your TTL (180 s here).
3. **Set `service_type = "ClusterIP"`** on each per-server minecraft entry in
   `terraform.tfvars` and `terraform apply`. Each minecraft Service loses its
   NodeBalancer; the CCM tears down the old NBs.
4. **Remove the per-server hostname annotations** (they're on ClusterIP
   Services now, external-dns still tracks them via TXT ownership; either drop
   the annotation in tfvars or let external-dns retire the stale records after
   the transition — it will notice mc-router owns them).

Once the dust settles with a dedicated mc-router NB: N minecraft NBs → 1. With `modules/gateway` in front (the default), → 0 extra NBs.

### Why not share ingress-nginx's NodeBalancer? (don't)

It's tempting to point mc-router at ingress-nginx's existing NodeBalancer
with ccm-linode's `service.beta.kubernetes.io/linode-loadbalancer-nodebalancer-id`
annotation and land on a single NB. **This does not work.** That annotation
is single-Service *adopt*, not multi-Service share: every LoadBalancer
Service's reconciler rewrites the NB's whole port-config list to match only
its own ports. With ingress-nginx (80/443) and mc-router (25565) on one NB,
whichever reconciled last wins and the other Service's ports vanish — we
lost ingress 80/443 this way. One LoadBalancer Service == one NodeBalancer.

The correct path to a single NB is what the root module does by default:
run mc-router as a `ClusterIP` Service (`service_type = "ClusterIP"`) behind
`modules/gateway`, whose one Gateway carries `tcp/25565` via a TCPRoute
alongside the HTTP(S) listeners. One LoadBalancer Service, one NB.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.6 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 3.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_helm"></a> [helm](#provider\_helm) | >= 3.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [helm_release.mc_router](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_mappings"></a> [mappings](#input\_mappings) | Mapping list turned into `minecraftRouter.mappings` on the itzg/mc-router<br>chart. Each entry routes an inbound Minecraft handshake for the given<br>hostname to the matching in-cluster Service. | <pre>list(object({<br>    hostname = string # external hostname minecraft clients dial (e.g. "mc1.example.com")<br>    target   = string # k8s Service address:port (e.g. "minecraft.minecraft.svc.cluster.local:25565")<br>  }))</pre> | n/a | yes |
| <a name="input_chart_version"></a> [chart\_version](#input\_chart\_version) | itzg/mc-router chart version. Pinned so upstream changes don't silently roll out. | `string` | `"1.5.0"` | no |
| <a name="input_external_port"></a> [external\_port](#input\_external\_port) | External Minecraft port exposed by the mc-router LoadBalancer Service. | `number` | `25565` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Kubernetes namespace to install mc-router into. | `string` | `"mc-router"` | no |
| <a name="input_service_type"></a> [service\_type](#input\_service\_type) | Service type for mc-router. `LoadBalancer` = its own NodeBalancer (external-dns hostnames published from the Service). `ClusterIP` = sit behind a Gateway API TCPRoute (modules/gateway), which then owns the hostnames. | `string` | `"LoadBalancer"` | no |

## Outputs

No outputs.
<!-- END_TF_DOCS -->