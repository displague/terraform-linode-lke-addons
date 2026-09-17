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

Once the dust settles: 5 NBs → 2 (`ingress-nginx` + `mc-router`).

<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_helm"></a> [helm](#provider\_helm) | n/a |

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
| <a name="input_share_nodebalancer_id"></a> [share\_nodebalancer\_id](#input\_share\_nodebalancer\_id) | Optional existing Linode NodeBalancer id to piggyback onto (typically<br>the id of the NB fronting ingress-nginx). ccm-linode adds a port<br>config for `external_port` to that NB instead of provisioning a<br>dedicated one for mc-router. Ports across the consuming Services must<br>not collide — mc-router on 25565 slots alongside ingress-nginx on<br>80/443 without conflict.<br><br>Also sets the `preserve` annotation so `helm uninstall mc-router`<br>doesn't delete the shared NB (it belongs to the other Service).<br><br>Uses ccm-linode's<br>`service.beta.kubernetes.io/linode-loadbalancer-nodebalancer-id`<br>annotation — see<br>https://github.com/linode/linode-cloud-controller-manager/blob/main/docs/configuration/annotations.md | `number` | `null` | no |

## Outputs

No outputs.
<!-- END_TF_DOCS -->