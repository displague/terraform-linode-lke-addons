<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_helm"></a> [helm](#provider\_helm) | n/a |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [helm_release.jupyterhub](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubernetes_namespace.jupyterhub](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_client_id"></a> [client\_id](#input\_client\_id) | n/a | `any` | n/a | yes |
| <a name="input_client_secret"></a> [client\_secret](#input\_client\_secret) | n/a | `any` | n/a | yes |
| <a name="input_gh_admin_users"></a> [gh\_admin\_users](#input\_gh\_admin\_users) | GitHub Admin Users | `list(string)` | n/a | yes |
| <a name="input_hostname"></a> [hostname](#input\_hostname) | n/a | `any` | n/a | yes |
| <a name="input_hub_db_volume"></a> [hub\_db\_volume](#input\_hub\_db\_volume) | n/a | `string` | `""` | no |
| <a name="input_proxy_service_type"></a> [proxy\_service\_type](#input\_proxy\_service\_type) | Kubernetes Service type for JupyterHub's `proxy-public`. The bundled<br>chart defaults to `LoadBalancer`, which on Linode spins a dedicated<br>NodeBalancer even though the module already wires up an<br>ingress-nginx-backed Ingress on `var.hostname`. Setting this to<br>`ClusterIP` drops the redundant NodeBalancer; traffic still reaches<br>users via the shared ingress-nginx entrypoint. | `string` | `"ClusterIP"` | no |

## Outputs

No outputs.
<!-- END_TF_DOCS -->