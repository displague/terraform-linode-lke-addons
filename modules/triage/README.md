<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.6 |
| <a name="requirement_kubectl"></a> [kubectl](#requirement\_kubectl) | >= 1.19.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_kubectl"></a> [kubectl](#provider\_kubectl) | >= 1.19.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [kubectl_manifest.triage_tinkerbell](https://registry.terraform.io/providers/gavinbunney/kubectl/latest/docs/resources/manifest) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_gh_token"></a> [gh\_token](#input\_gh\_token) | n/a | `string` | n/a | yes |
| <a name="input_triage_host"></a> [triage\_host](#input\_triage\_host) | n/a | `string` | n/a | yes |
| <a name="input_create_ingress"></a> [create\_ingress](#input\_create\_ingress) | Apply the Ingress asset for `triage_host`. Leave false (the default via the root module) when the host is routed by modules/gateway (an HTTPRoute); only useful with a bring-your-own ingress controller. | `bool` | `true` | no |

## Outputs

No outputs.
<!-- END_TF_DOCS -->