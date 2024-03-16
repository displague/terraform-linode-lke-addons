<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_linode"></a> [linode](#provider\_linode) | 1.20.2 |
| <a name="provider_local"></a> [local](#provider\_local) | 2.1.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [linode_lke_cluster.lke](https://registry.terraform.io/providers/linode/linode/latest/docs/resources/lke_cluster) | resource |
| [local_file.lke_config](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_lke_config"></a> [lke\_config](#input\_lke\_config) | n/a | `any` | n/a | yes |
| <a name="input_k8s_version"></a> [k8s\_version](#input\_k8s\_version) | n/a | `string` | `"1.26"` | no |
| <a name="input_max_count"></a> [max\_count](#input\_max\_count) | n/a | `number` | `3` | no |
| <a name="input_min_count"></a> [min\_count](#input\_min\_count) | n/a | `number` | `1` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_lke_config"></a> [lke\_config](#output\_lke\_config) | n/a |
| <a name="output_lke_id"></a> [lke\_id](#output\_lke\_id) | ID of the Linode LKE Cluster created |
<!-- END_TF_DOCS -->