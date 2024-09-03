## LKE with Extras

This Terraform module provisions Linode Kubernetes Engine (LKE) with common add-ons:

- External DNS
  External DNS is configured with a Linode API token scoped to DNS services.
- Cert Manager
  cert-manager is configured with an HTTP prover (which uses nginx-ingress).
- Nginx Ingress Controller
  This default ingress controller will use a single LoadBalancer Service for all Ingress objects.
  The Ingress is configured with 0.2.1 of <https://github.com/compumike/hairpin-proxy#hairpin-proxy> which fixes problems with using the proxy protocol. (See the link for more details)

## Variables

See `terraform.tfvars.sample`. Copy this to `terraform.tfvars` and modify as needed.

## Install

```sh
terraform apply
```

<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_cert_manager"></a> [cert\_manager](#module\_cert\_manager) | ./modules/cert_manager | n/a |
| <a name="module_external_dns"></a> [external\_dns](#module\_external\_dns) | ./modules/external_dns | n/a |
| <a name="module_ingress_nginx"></a> [ingress\_nginx](#module\_ingress\_nginx) | ./modules/ingress_nginx | n/a |
| <a name="module_jhub"></a> [jhub](#module\_jhub) | ./modules/jhub | n/a |
| <a name="module_lke"></a> [lke](#module\_lke) | ./modules/kube | n/a |
| <a name="module_longhorn"></a> [longhorn](#module\_longhorn) | ./modules/longhorn | n/a |
| <a name="module_minecraft"></a> [minecraft](#module\_minecraft) | ./modules/minecraft | n/a |
| <a name="module_triage"></a> [triage](#module\_triage) | ./modules/triage | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_example_host"></a> [example\_host](#input\_example\_host) | If set, an ingress will be created with this hostname used. The domain should be one managed by your Linode account. | `any` | n/a | yes |
| <a name="input_issuer_email"></a> [issuer\_email](#input\_issuer\_email) | An email address for ACME certificate registration. | `any` | n/a | yes |
| <a name="input_linode_token"></a> [linode\_token](#input\_linode\_token) | Your Linode API Authentication Token. | `any` | n/a | yes |
| <a name="input_minecraft"></a> [minecraft](#input\_minecraft) | A list of minecraft servers to deploy. Each object should have the following fields:<br>- namespace: the namespace of the minecraft server<br>- port: the port to run the minecraft server on<br>- ops: a list of minecraft usernames that will receive ops<br>- motd: the minecraft MOTD<br>- hostname: the hostname where minecraft will run<br>- claim: existing claim | <pre>list(object(<br>    {<br>      namespace = string<br>      port      = number<br>      ops       = string<br>      motd      = string<br>      hostname  = string<br>      claim     = string<br>    }<br>  ))</pre> | n/a | yes |
| <a name="input_gh_admin_users"></a> [gh\_admin\_users](#input\_gh\_admin\_users) | GH admin\_users for JupyterHub | `list(string)` | `[]` | no |
| <a name="input_gh_token"></a> [gh\_token](#input\_gh\_token) | GH token for triage party | `string` | `""` | no |
| <a name="input_jhub_client_id"></a> [jhub\_client\_id](#input\_jhub\_client\_id) | GH client\_id for jhub | `string` | `""` | no |
| <a name="input_jhub_client_secret"></a> [jhub\_client\_secret](#input\_jhub\_client\_secret) | GH client\_secret for jhub | `string` | `""` | no |
| <a name="input_jhub_db_volume"></a> [jhub\_db\_volume](#input\_jhub\_db\_volume) | PVC name for Hub DB Volume | `string` | `""` | no |
| <a name="input_jhub_hostname"></a> [jhub\_hostname](#input\_jhub\_hostname) | hostname for jupyter hub | `string` | `""` | no |
| <a name="input_k8s_version"></a> [k8s\_version](#input\_k8s\_version) | LKE K8s Version | `string` | `"1.26"` | no |
| <a name="input_longhorn_enabled"></a> [longhorn\_enabled](#input\_longhorn\_enabled) | Whether Longhorn should be installed | `bool` | `false` | no |
| <a name="input_triage_host"></a> [triage\_host](#input\_triage\_host) | hostname where triage party will reside | `string` | `""` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_lke_id"></a> [lke\_id](#output\_lke\_id) | n/a |
<!-- END_TF_DOCS -->