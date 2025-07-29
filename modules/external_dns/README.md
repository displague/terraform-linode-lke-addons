<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_helm"></a> [helm](#provider\_helm) | 2.3.0 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | 2.4.1 |
| <a name="provider_linode"></a> [linode](#provider\_linode) | 1.20.2 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [helm_release.external_dns](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubernetes_namespace.external_dns](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) | resource |
| [kubernetes_secret.external_dns](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret) | resource |
| [linode_token.external_dns](https://registry.terraform.io/providers/linode/linode/latest/docs/resources/token) | resource |

## Inputs

| Name | Description | Type | Default |
|------|-------------|------|---------|
| external_dns_token_expiry | Expiry date for the Linode API token used by external-dns. RFC3339 format. | string | n/a |

## Outputs

No outputs.
<!-- END_TF_DOCS -->