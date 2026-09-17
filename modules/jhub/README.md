## JupyterHub module

Wraps the upstream JupyterHub Helm chart with a Linode-friendly default:
`ingress` on port 443 via ingress-nginx, `proxy-public` Service left at
`ClusterIP` (so no dedicated NodeBalancer just for jhub), and — new in
this revision — a terraform-managed PVC for the hub's sqlite database.

### PVC ownership

The chart's built-in `hub.db.type = sqlite-pvc` mode creates a PVC from
its own template. Upstream `values.schema.json` has been aggressively
tightening what's allowed on that PVC (`volumeName` was dropped in the
2025 series), which makes any subsequent `helm upgrade` fail:

    Upgrade failed: failed to replace object: PersistentVolumeClaim "hub-db-dir"
    is invalid: spec: Forbidden: spec is immutable after creation except
    resources.requests and volumeAttributesClassName for bound claims

To avoid that trap the module flips `hub.db.type = "other"`, mounts a
terraform-managed PVC (`kubernetes_persistent_volume_claim.hub_db`) at
the same `/srv/jupyterhub` path the chart's PVC mode used, and points
`hub.db.url` at the same sqlite file. From the hub's perspective
nothing changed — same file, same path — but the PVC lifecycle now
lives outside helm, matching the pattern `modules/minecraft` adopted
in #26.

Inputs:
- `hub_db_claim` — PVC name. Defaults to `"hub-db-dir"` to match the
  historical chart-generated name for a zero-downtime migration.
- `hub_db_volume` — optional pre-existing PV to bind (recovery /
  world-move workflow). Leave `""` for dynamic provisioning.
- `hub_db_storage_size` (default `"10Gi"`), `hub_db_storage_class`
  (default `"linode-block-storage-retain"`).

#### Migrating an existing chart-managed PVC

If your cluster already has a chart-managed `hub-db-dir` PVC (i.e. jhub
was installed by a prior revision of this module), `terraform apply`
after upgrading will fail because the PVC already exists and isn't in
state. Migration is three commands:

```sh
# 1. Tell helm not to delete the k8s PVC when it drops it from its
#    tracked resources (which will happen once hub.db.type = "other"
#    causes the chart to stop rendering a PVC template).
kubectl -n jupyterhub annotate --overwrite pvc/hub-db-dir \
  helm.sh/resource-policy=keep

# 2. Import the running PVC into terraform state.
terraform import 'module.jhub[0].kubernetes_persistent_volume_claim.hub_db' \
  'jupyterhub/hub-db-dir'

# 3. Apply. Helm renders the chart without its own PVC template,
#    notices the annotation, leaves the k8s PVC alone. Terraform now
#    owns it. The chart's new `extraVolumes` mount points at the same
#    PVC at the same path — the hub sees no change.
terraform apply
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.6 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 3.0.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.38.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_helm"></a> [helm](#provider\_helm) | >= 3.0.0 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | >= 2.38.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [helm_release.jupyterhub](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubernetes_namespace.jupyterhub](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) | resource |
| [kubernetes_persistent_volume_claim.hub_db](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/persistent_volume_claim) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_client_id"></a> [client\_id](#input\_client\_id) | n/a | `string` | n/a | yes |
| <a name="input_client_secret"></a> [client\_secret](#input\_client\_secret) | n/a | `string` | n/a | yes |
| <a name="input_gh_admin_users"></a> [gh\_admin\_users](#input\_gh\_admin\_users) | GitHub Admin Users | `list(string)` | n/a | yes |
| <a name="input_hostname"></a> [hostname](#input\_hostname) | n/a | `string` | n/a | yes |
| <a name="input_create_ingress"></a> [create\_ingress](#input\_create\_ingress) | Render the chart's own Ingress for `hostname`. Leave false (the default via the root module) when the host is routed by modules/gateway (an HTTPRoute); only useful with a bring-your-own ingress controller. | `bool` | `true` | no |
| <a name="input_hub_db_claim"></a> [hub\_db\_claim](#input\_hub\_db\_claim) | Name of the terraform-managed PVC that stores the hub sqlite database.<br>Default matches the historical chart-generated name for zero-downtime<br>migration from `hub.db.type = sqlite-pvc`. | `string` | `"hub-db-dir"` | no |
| <a name="input_hub_db_storage_class"></a> [hub\_db\_storage\_class](#input\_hub\_db\_storage\_class) | Storage class for the hub sqlite PVC. `Retain` reclaim is what makes recovery possible when things go sideways. | `string` | `"linode-block-storage-retain"` | no |
| <a name="input_hub_db_storage_size"></a> [hub\_db\_storage\_size](#input\_hub\_db\_storage\_size) | Requested size of the hub sqlite PVC. 1Gi matches the upstream chart's<br>historical default. Note that on Linode Block Storage the underlying<br>PV is provisioned at the storage class minimum (10Gi) regardless of<br>the request, so keeping this small doesn't cost anything. | `string` | `"1Gi"` | no |
| <a name="input_hub_db_volume"></a> [hub\_db\_volume](#input\_hub\_db\_volume) | Optional pre-existing PersistentVolume name to bind the hub sqlite PVC<br>to. Set this when adopting the module for an existing chart-managed<br>PVC (`Retain` policy preserves the PV across the migration). Leave ""<br>to let the storage class dynamically provision a fresh PV. | `string` | `""` | no |
| <a name="input_proxy_service_type"></a> [proxy\_service\_type](#input\_proxy\_service\_type) | Kubernetes Service type for JupyterHub's `proxy-public`. The bundled<br>chart defaults to `LoadBalancer`, which on Linode spins a dedicated<br>NodeBalancer even though the hub is reached through the cluster's<br>shared Gateway (an HTTPRoute on `var.hostname`). `ClusterIP` (the<br>default here) avoids that extra NodeBalancer. | `string` | `"ClusterIP"` | no |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
