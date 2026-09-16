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
