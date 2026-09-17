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

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.6 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 3.0.0 |
| <a name="requirement_http"></a> [http](#requirement\_http) | >= 3.4.0 |
| <a name="requirement_kubectl"></a> [kubectl](#requirement\_kubectl) | >= 1.19.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.38.0 |
| <a name="requirement_linode"></a> [linode](#requirement\_linode) | ~> 4.0 |
| <a name="requirement_local"></a> [local](#requirement\_local) | >= 2.5.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_http"></a> [http](#provider\_http) | 3.6.2 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_cert_manager"></a> [cert\_manager](#module\_cert\_manager) | ./modules/cert_manager | n/a |
| <a name="module_external_dns"></a> [external\_dns](#module\_external\_dns) | ./modules/external_dns | n/a |
| <a name="module_ingress_nginx"></a> [ingress\_nginx](#module\_ingress\_nginx) | ./modules/ingress_nginx | n/a |
| <a name="module_jhub"></a> [jhub](#module\_jhub) | ./modules/jhub | n/a |
| <a name="module_lke"></a> [lke](#module\_lke) | ./modules/kube | n/a |
| <a name="module_longhorn"></a> [longhorn](#module\_longhorn) | ./modules/longhorn | n/a |
| <a name="module_mc_router"></a> [mc\_router](#module\_mc\_router) | ./modules/mc_router | n/a |
| <a name="module_minecraft"></a> [minecraft](#module\_minecraft) | ./modules/minecraft | n/a |
| <a name="module_triage"></a> [triage](#module\_triage) | ./modules/triage | n/a |

## Resources

| Name | Type |
|------|------|
| [http_http.my_ipv4](https://registry.terraform.io/providers/hashicorp/http/latest/docs/data-sources/http) | data source |
| [http_http.my_ipv6](https://registry.terraform.io/providers/hashicorp/http/latest/docs/data-sources/http) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_example_host"></a> [example\_host](#input\_example\_host) | If set, an ingress will be created with this hostname used. The domain should be one managed by your Linode account. | `any` | n/a | yes |
| <a name="input_external_dns_token_expiry"></a> [external\_dns\_token\_expiry](#input\_external\_dns\_token\_expiry) | Expiry date for the Linode API token used by external-dns. RFC3339 format. | `string` | n/a | yes |
| <a name="input_issuer_email"></a> [issuer\_email](#input\_issuer\_email) | An email address for ACME certificate registration. | `any` | n/a | yes |
| <a name="input_linode_token"></a> [linode\_token](#input\_linode\_token) | Your Linode API Authentication Token. | `any` | n/a | yes |
| <a name="input_minecraft"></a> [minecraft](#input\_minecraft) | A list of minecraft servers to deploy. Each object should have the following fields:<br>- namespace: the namespace of the minecraft server<br>- port: the port to run the minecraft server on<br>- ops: a list of minecraft usernames that will receive ops<br>- motd: the minecraft MOTD<br>- hostname: the hostname where minecraft will run<br>- claim: existing claim<br>- mc\_version: (optional) itzg image `VERSION` — pin to a specific minecraft<br>  version like "1.21.8" when restoring a world from a much older DataVersion.<br>  Defaults to "LATEST". | <pre>list(object(<br>    {<br>      namespace    = string<br>      port         = number<br>      ops          = string<br>      motd         = string<br>      hostname     = string<br>      claim        = string<br>      mc_version   = optional(string, "LATEST")<br>      service_type = optional(string, "LoadBalancer")<br>    }<br>  ))</pre> | n/a | yes |
| <a name="input_gh_admin_users"></a> [gh\_admin\_users](#input\_gh\_admin\_users) | GH admin\_users for JupyterHub | `list(string)` | `[]` | no |
| <a name="input_gh_token"></a> [gh\_token](#input\_gh\_token) | GH token for triage party | `string` | `""` | no |
| <a name="input_jhub_client_id"></a> [jhub\_client\_id](#input\_jhub\_client\_id) | GH client\_id for jhub | `string` | `""` | no |
| <a name="input_jhub_client_secret"></a> [jhub\_client\_secret](#input\_jhub\_client\_secret) | GH client\_secret for jhub | `string` | `""` | no |
| <a name="input_jhub_db_volume"></a> [jhub\_db\_volume](#input\_jhub\_db\_volume) | PVC name for Hub DB Volume | `string` | `""` | no |
| <a name="input_jhub_hostname"></a> [jhub\_hostname](#input\_jhub\_hostname) | hostname for jupyter hub | `string` | `""` | no |
| <a name="input_k8s_version"></a> [k8s\_version](#input\_k8s\_version) | LKE K8s Version. Keep within Linode's currently-supported window (`linode-cli lke versions-list`). | `string` | `"1.36"` | no |
| <a name="input_lke_acl_allow_my_ip"></a> [lke\_acl\_allow\_my\_ip](#input\_lke\_acl\_allow\_my\_ip) | Also add whatever public IPv4 the terraform-runner has right now to the<br>ACL allow list. Uses `data "http"` against ipv4.icanhazip.com. Handy for<br>home / office runners on residential NAT — but be aware the IP can<br>change, in which case a subsequent apply is needed to keep access.<br>Ignored if `lke_acl_enabled = false`. | `bool` | `false` | no |
| <a name="input_lke_acl_enabled"></a> [lke\_acl\_enabled](#input\_lke\_acl\_enabled) | Manage the LKE control-plane ACL from terraform. When `false` the module<br>leaves the ACL untouched (Cloud UI / API manages it). When `true`,<br>terraform applies the enabled=true policy with the ipv4 / ipv6 lists<br>below plus (optionally) the caller's current public IP. | `bool` | `false` | no |
| <a name="input_lke_acl_ipv4"></a> [lke\_acl\_ipv4](#input\_lke\_acl\_ipv4) | IPv4 CIDRs to allow through the LKE control-plane ACL. Ignored if `lke_acl_enabled = false`. | `list(string)` | `[]` | no |
| <a name="input_lke_acl_ipv6"></a> [lke\_acl\_ipv6](#input\_lke\_acl\_ipv6) | IPv6 CIDRs to allow through the LKE control-plane ACL. Ignored if `lke_acl_enabled = false`. | `list(string)` | `[]` | no |
| <a name="input_longhorn_enabled"></a> [longhorn\_enabled](#input\_longhorn\_enabled) | Whether Longhorn should be installed | `bool` | `false` | no |
| <a name="input_mc_router_enabled"></a> [mc\_router\_enabled](#input\_mc\_router\_enabled) | When true, deploy `modules/mc_router` (a single LoadBalancer that routes<br>all minecraft traffic by handshake hostname) and force every entry in<br>`var.minecraft` to `service_type = ClusterIP`. Consolidates N per-server<br>NodeBalancers down to one. Requires clients to keep dialing the same<br>per-server hostnames. | `bool` | `false` | no |
| <a name="input_mc_router_share_nodebalancer_id"></a> [mc\_router\_share\_nodebalancer\_id](#input\_mc\_router\_share\_nodebalancer\_id) | Optional existing Linode NodeBalancer id to piggyback mc-router onto —<br>typically the id of the NB fronting ingress-nginx. When set, ccm-linode<br>adds a port config for 25565 to that NB instead of provisioning a<br>dedicated one for mc-router. Ports across the consumer Services must<br>not collide (25565 alongside 80/443 is fine).<br><br>Only meaningful when `mc_router_enabled = true`. Get the id from<br>`kubectl -n ingress-nginx get svc ingress-nginx-controller -o jsonpath='{.metadata.annotations.service\.beta\.kubernetes\.io/linode-loadbalancer-nodebalancer-id}'`<br>once ingress-nginx is up. | `number` | `null` | no |
| <a name="input_triage_host"></a> [triage\_host](#input\_triage\_host) | hostname where triage party will reside | `string` | `""` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_lke_id"></a> [lke\_id](#output\_lke\_id) | n/a |
<!-- END_TF_DOCS -->