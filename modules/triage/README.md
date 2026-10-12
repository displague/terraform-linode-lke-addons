# triage

Installs [Triage Party](https://github.com/google/triage-party) into
`namespace` (default `triage`): GitHub token Secret, config, Deployment,
and Service. `repos` is the list of GitHub repositories it reads, `name`
is the display name, and `triage_host` is the public hostname.

`create_ingress` also applies an Ingress for that host. Leave it false
when `modules/gateway` publishes the host with an HTTPRoute; the root
module does that whenever the Gateway is enabled.

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
| [kubectl_manifest.triage](https://registry.terraform.io/providers/gavinbunney/kubectl/latest/docs/resources/manifest) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_gh_token"></a> [gh\_token](#input\_gh\_token) | n/a | `string` | n/a | yes |
| <a name="input_repos"></a> [repos](#input\_repos) | GitHub repositories to triage, as https://github.com/org/repo URLs. | `list(string)` | n/a | yes |
| <a name="input_triage_host"></a> [triage\_host](#input\_triage\_host) | n/a | `string` | n/a | yes |
| <a name="input_create_ingress"></a> [create\_ingress](#input\_create\_ingress) | Apply the Ingress asset for `triage_host`. Leave false (the default via the root module) when the host is routed by modules/gateway (an HTTPRoute); only useful with a bring-your-own ingress controller. | `bool` | `true` | no |
| <a name="input_name"></a> [name](#input\_name) | Display name Triage Party shows for this site. | `string` | `"Triage"` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Namespace for Triage Party. | `string` | `"triage"` | no |

## Outputs

No outputs.
<!-- END_TF_DOCS -->