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
| [helm_release.minecraft](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_hostname"></a> [hostname](#input\_hostname) | DNS Hostname for the server | `any` | n/a | yes |
| <a name="input_motd"></a> [motd](#input\_motd) | Message of the Day | `any` | n/a | yes |
| <a name="input_ops"></a> [ops](#input\_ops) | Admin accounts for minecraft server. These account names must be valid. | `any` | n/a | yes |
| <a name="input_claim"></a> [claim](#input\_claim) | Existing claim to reuse. Between reuses be sure to clear the claimRef of the Released pv. `kubectl patch pv $PV_NAME -p '{"spec":{"claimRef": null}}'` | `string` | `""` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | n/a | `string` | `"minecraft"` | no |
| <a name="input_port"></a> [port](#input\_port) | n/a | `number` | `25565` | no |

## Outputs

No outputs.
<!-- END_TF_DOCS -->