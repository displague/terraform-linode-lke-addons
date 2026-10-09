# registry_auth

Docker Hub pull credentials for namespaces whose pods pull from Docker Hub: a
`kubernetes.io/dockerconfigjson` Secret per namespace, attached to each listed
namespace's `default` ServiceAccount. Kubernetes has no cluster-wide pull secret,
and anonymous Docker Hub pulls are rate-limited per source IP.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.6 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.38.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | >= 2.38.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [kubernetes_default_service_account_v1.default](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/default_service_account_v1) | resource |
| [kubernetes_secret_v1.dockerhub](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret_v1) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_namespaces"></a> [namespaces](#input\_namespaces) | Namespaces that get the pull Secret. | `list(string)` | n/a | yes |
| <a name="input_token"></a> [token](#input\_token) | Docker Hub personal access token, read-only on public repositories is enough. | `string` | n/a | yes |
| <a name="input_username"></a> [username](#input\_username) | Docker Hub username that owns the access token. | `string` | n/a | yes |
| <a name="input_default_service_account_namespaces"></a> [default\_service\_account\_namespaces](#input\_default\_service\_account\_namespaces) | Subset of `namespaces` whose `default` ServiceAccount should use the Secret (pods that don't name their own ServiceAccount). | `list(string)` | `[]` | no |
| <a name="input_secret_name"></a> [secret\_name](#input\_secret\_name) | Name of the pull Secret in each namespace. | `string` | `"dockerhub"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_secret_name"></a> [secret\_name](#output\_secret\_name) | Name of the pull Secret, for charts that take `imagePullSecrets`. |
<!-- END_TF_DOCS -->
