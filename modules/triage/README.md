<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_kubectl"></a> [kubectl](#provider\_kubectl) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [kubectl_manifest.triage_tinkerbell](https://registry.terraform.io/providers/gavinbunney/kubectl/latest/docs/resources/manifest) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_gh_token"></a> [gh\_token](#input\_gh\_token) | n/a | `any` | n/a | yes |
| <a name="input_triage_host"></a> [triage\_host](#input\_triage\_host) | n/a | `any` | n/a | yes |
| <a name="input_create_ingress"></a> [create\_ingress](#input\_create\_ingress) | Apply the nginx Ingress asset for `triage_host`. Set false when the host is routed by modules/gateway (an HTTPRoute) instead. | `bool` | `true` | no |

## Outputs

No outputs.
<!-- END_TF_DOCS -->