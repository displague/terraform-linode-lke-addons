# cosi

Installs the [Linode COSI driver](https://github.com/linode/linode-cosi-driver)
(Container Object Storage Interface) Helm chart with a Linode personal access
token scoped to `object_storage:read_write`.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.6 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 3.0.0 |
| <a name="requirement_linode"></a> [linode](#requirement\_linode) | ~> 4.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_helm"></a> [helm](#provider\_helm) | >= 3.0.0 |
| <a name="provider_linode"></a> [linode](#provider\_linode) | ~> 4.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [helm_release.linode_cosi_driver](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [linode_token.cosi](https://registry.terraform.io/providers/linode/linode/latest/docs/resources/token) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_token_expiry"></a> [token\_expiry](#input\_token\_expiry) | Expiry date for the Linode API token used by linode-cosi-driver (`object_storage:read_write`). RFC3339 format. | `string` | n/a | yes |
| <a name="input_chart_version"></a> [chart\_version](#input\_chart\_version) | linode-cosi-driver Helm chart version. | `string` | `"0.9.5"` | no |
| <a name="input_image_pull_secrets"></a> [image\_pull\_secrets](#input\_image\_pull\_secrets) | Docker registry pull Secret names in `namespace` for the driver Deployment (`docker.io/linode/linode-cosi-driver`). | `list(string)` | `[]` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Namespace to install linode-cosi-driver into. | `string` | `"linode-cosi-driver"` | no |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
