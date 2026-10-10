## LKE with Extras

This Terraform module provisions Linode Kubernetes Engine (LKE) with common add-ons:

- External DNS
  External DNS is configured with a Linode API token scoped to DNS services.
- Cert Manager
  cert-manager is configured with a Linode DNS-01 solver and issues certificates for the Gateway's HTTPS listeners.
- Gateway API entrypoint (Envoy Gateway)
  One `Gateway` with `http/80` (redirect), one `https/443` listener per hostname, and `tcp/25565` for Minecraft — one LoadBalancer Service, one Linode NodeBalancer. Replaces ingress-nginx (unmaintained since March 2026) and the hairpin-proxy workaround it needed.
- Minecraft (itzg), mc-router, JupyterHub, Triage Party, Longhorn — optional add-ons, see `modules/`.

## Variables

See `terraform.tfvars.sample`. Copy this to `terraform.tfvars` and modify as needed.

## Install

```sh
terraform apply
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.6 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 3.0.0 |
| <a name="requirement_http"></a> [http](#requirement\_http) | >= 3.4.0 |
| <a name="requirement_kubectl"></a> [kubectl](#requirement\_kubectl) | >= 1.19.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.38.0 |
| <a name="requirement_linode"></a> [linode](#requirement\_linode) | ~> 4.0 |
| <a name="requirement_local"></a> [local](#requirement\_local) | >= 2.5.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_http"></a> [http](#provider\_http) | 3.6.2 |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_cert_manager"></a> [cert\_manager](#module\_cert\_manager) | ./modules/cert_manager | n/a |
| <a name="module_cloud_firewall"></a> [cloud\_firewall](#module\_cloud\_firewall) | ./modules/cloud_firewall | n/a |
| <a name="module_external_dns"></a> [external\_dns](#module\_external\_dns) | ./modules/external_dns | n/a |
| <a name="module_gateway"></a> [gateway](#module\_gateway) | ./modules/gateway | n/a |
| <a name="module_github_runners"></a> [github\_runners](#module\_github\_runners) | ./modules/github_runners | n/a |
| <a name="module_jhub"></a> [jhub](#module\_jhub) | ./modules/jhub | n/a |
| <a name="module_lke"></a> [lke](#module\_lke) | ./modules/kube | n/a |
| <a name="module_longhorn"></a> [longhorn](#module\_longhorn) | ./modules/longhorn | n/a |
| <a name="module_mc_router"></a> [mc\_router](#module\_mc\_router) | ./modules/mc_router | n/a |
| <a name="module_minecraft"></a> [minecraft](#module\_minecraft) | ./modules/minecraft | n/a |
| <a name="module_registry_auth"></a> [registry\_auth](#module\_registry\_auth) | ./modules/registry_auth | n/a |
| <a name="module_triage"></a> [triage](#module\_triage) | ./modules/triage | n/a |

## Resources

| Name | Type |
| ---- | ---- |
| [terraform_data.dockerhub_token_expiry](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [http_http.my_ipv4](https://registry.terraform.io/providers/hashicorp/http/latest/docs/data-sources/http) | data source |
| [http_http.my_ipv6](https://registry.terraform.io/providers/hashicorp/http/latest/docs/data-sources/http) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_example_host"></a> [example\_host](#input\_example\_host) | If set, an ingress will be created with this hostname used. The domain should be one managed by your Linode account. | `string` | n/a | yes |
| <a name="input_external_dns_token_expiry"></a> [external\_dns\_token\_expiry](#input\_external\_dns\_token\_expiry) | Expiry date for the Linode API token used by external-dns. RFC3339 format. | `string` | n/a | yes |
| <a name="input_issuer_email"></a> [issuer\_email](#input\_issuer\_email) | An email address for ACME certificate registration. | `string` | n/a | yes |
| <a name="input_linode_token"></a> [linode\_token](#input\_linode\_token) | Your Linode API Authentication Token. | `string` | n/a | yes |
| <a name="input_minecraft"></a> [minecraft](#input\_minecraft) | A list of minecraft servers to deploy. Each object should have the following fields:<br/>- namespace: the namespace of the minecraft server<br/>- port: the port to run the minecraft server on<br/>- ops: a list of minecraft usernames that will receive ops<br/>- motd: the minecraft MOTD<br/>- hostname: the hostname where minecraft will run<br/>- claim: existing claim<br/>- mc\_version: (optional) itzg image `VERSION` — pin to a specific minecraft<br/>  version like "1.21.8" when restoring a world from a much older DataVersion.<br/>  Defaults to "LATEST". | <pre>list(object(<br/>    {<br/>      namespace    = string<br/>      port         = number<br/>      ops          = string<br/>      motd         = string<br/>      hostname     = string<br/>      claim        = string<br/>      mc_version   = optional(string, "LATEST")<br/>      service_type = optional(string, "LoadBalancer")<br/>    }<br/>  ))</pre> | n/a | yes |
| <a name="input_cloud_firewall_enabled"></a> [cloud\_firewall\_enabled](#input\_cloud\_firewall\_enabled) | Install Linode's cloud-firewall-controller (modules/cloud\_firewall), which<br/>keeps every node, including future ones, attached to a Cloud Firewall that<br/>only admits the LKE control plane, the nodes and NodeBalancers. Without<br/>it, NodePorts are reachable from the internet, bypassing the<br/>NodeBalancer. Uses LKE's existing API credential; no new token. | `bool` | `false` | no |
| <a name="input_dockerhub_token"></a> [dockerhub\_token](#input\_dockerhub\_token) | Docker Hub personal access token (read-only on public repositories is enough). Used with dockerhub\_username. | `string` | `""` | no |
| <a name="input_dockerhub_token_expiry"></a> [dockerhub\_token\_expiry](#input\_dockerhub\_token\_expiry) | When dockerhub\_token expires, RFC3339 (e.g. 2027-10-09T00:00:00Z). Plans fail once it has passed and warn in the 30 days before. Empty skips the check. | `string` | `""` | no |
| <a name="input_dockerhub_username"></a> [dockerhub\_username](#input\_dockerhub\_username) | Docker Hub username for authenticated image pulls. Empty pulls anonymously (rate-limited per IP). | `string` | `""` | no |
| <a name="input_extra_http_routes"></a> [extra\_http\_routes](#input\_extra\_http\_routes) | Additional HTTP(S) hosts to route through the Gateway to an existing in-cluster Service (`namespace/service:port`). Each gets its own HTTPS listener + certificate. | <pre>list(object({<br/>    hostname        = string<br/>    namespace       = string<br/>    service         = string<br/>    port            = number<br/>    request_timeout = optional(string, "0s")<br/>  }))</pre> | `[]` | no |
| <a name="input_gateway_enabled"></a> [gateway\_enabled](#input\_gateway\_enabled) | Front the cluster with a single Gateway API Gateway (modules/gateway,<br/>Envoy Gateway) instead of ingress-nginx + a separate mc-router<br/>LoadBalancer. When true: HTTPRoutes are created for the jhub / triage /<br/>example hosts and `extra_http_routes`, a TCPRoute fronts mc-router<br/>(which drops to ClusterIP), cert-manager's gateway-shim is enabled, and<br/>external-dns switches to the gateway-httproute / gateway-tcproute<br/>sources. This is the cluster's only entrypoint; set false only if you<br/>bring your own ingress. | `bool` | `true` | no |
| <a name="input_gateway_ipv6_ingress"></a> [gateway\_ipv6\_ingress](#input\_gateway\_ipv6\_ingress) | Publish an IPv6 address on the Gateway's NodeBalancer too (frontend only; no dual-stack cluster needed). external-dns then adds AAAA records. | `bool` | `true` | no |
| <a name="input_gateway_proxy_protocol"></a> [gateway\_proxy\_protocol](#input\_gateway\_proxy\_protocol) | Real client IPs at the Gateway via PROXY protocol: `off`, `accept` (Envoy accepts an optional header) or `on` (the NodeBalancer also sends it). Roll out `accept` before `on`, and enable `cloud_firewall_enabled` first. See modules/gateway. | `string` | `"off"` | no |
| <a name="input_gh_admin_users"></a> [gh\_admin\_users](#input\_gh\_admin\_users) | GH admin\_users for JupyterHub | `list(string)` | `[]` | no |
| <a name="input_gh_token"></a> [gh\_token](#input\_gh\_token) | GH token for triage party | `string` | `""` | no |
| <a name="input_github_runner_app"></a> [github\_runner\_app](#input\_github\_runner\_app) | GitHub App credentials for the runners, preferred over `github_runner_token`. | <pre>object({<br/>    app_id          = string<br/>    installation_id = string<br/>    private_key     = string<br/>  })</pre> | `null` | no |
| <a name="input_github_runner_scale_sets"></a> [github\_runner\_scale\_sets](#input\_github\_runner\_scale\_sets) | Self-hosted GitHub Actions runner scale sets (modules/github\_runners),<br/>keyed by the name workflows use in `runs-on`. Empty installs nothing.<br/>Needs `github_runner_token` or `github_runner_app`. Use them for private<br/>repositories only, and keep pipelines that manage this cluster on<br/>GitHub-hosted runners. | <pre>map(object({<br/>    config_url     = string<br/>    min_runners    = optional(number, 0)<br/>    max_runners    = optional(number, 2)<br/>    cpu_request    = optional(string, "500m")<br/>    memory_request = optional(string, "1Gi")<br/>    memory_limit   = optional(string, "3Gi")<br/>  }))</pre> | `{}` | no |
| <a name="input_github_runner_token"></a> [github\_runner\_token](#input\_github\_runner\_token) | Fine-grained GitHub token with Administration read/write on the runner repositories. | `string` | `null` | no |
| <a name="input_jhub_client_id"></a> [jhub\_client\_id](#input\_jhub\_client\_id) | GH client\_id for jhub | `string` | `""` | no |
| <a name="input_jhub_client_secret"></a> [jhub\_client\_secret](#input\_jhub\_client\_secret) | GH client\_secret for jhub | `string` | `""` | no |
| <a name="input_jhub_db_volume"></a> [jhub\_db\_volume](#input\_jhub\_db\_volume) | PVC name for Hub DB Volume | `string` | `""` | no |
| <a name="input_jhub_hostname"></a> [jhub\_hostname](#input\_jhub\_hostname) | hostname for jupyter hub | `string` | `""` | no |
| <a name="input_k8s_version"></a> [k8s\_version](#input\_k8s\_version) | LKE K8s Version. Keep within Linode's currently-supported window (`linode-cli lke versions-list`). | `string` | `"1.36"` | no |
| <a name="input_kubeconfig_path"></a> [kubeconfig\_path](#input\_kubeconfig\_path) | Where to write the cluster's kubeconfig, which the kubernetes, kubectl<br/>and helm providers read. Defaults to `kube.config` in this module's<br/>directory. Set it when calling this repository as a module (for example<br/>`"${path.root}/kube.config"`), so a CI job can fetch the kubeconfig from<br/>the Linode API before `terraform plan` on a fresh runner. | `string` | `null` | no |
| <a name="input_lke_acl_allow_my_ip"></a> [lke\_acl\_allow\_my\_ip](#input\_lke\_acl\_allow\_my\_ip) | Also add whatever public IPv4 the terraform-runner has right now to the<br/>ACL allow list. Uses `data "http"` against ipv4.icanhazip.com. Handy for<br/>home / office runners on residential NAT — but be aware the IP can<br/>change, in which case a subsequent apply is needed to keep access.<br/>Ignored if `lke_acl_enabled = false`. | `bool` | `false` | no |
| <a name="input_lke_acl_enabled"></a> [lke\_acl\_enabled](#input\_lke\_acl\_enabled) | Manage the LKE control-plane ACL from terraform. When `false` the module<br/>leaves the ACL untouched (Cloud UI / API manages it). When `true`,<br/>terraform applies the enabled=true policy with the ipv4 / ipv6 lists<br/>below plus (optionally) the caller's current public IP. | `bool` | `false` | no |
| <a name="input_lke_acl_ipv4"></a> [lke\_acl\_ipv4](#input\_lke\_acl\_ipv4) | IPv4 CIDRs to allow through the LKE control-plane ACL. Ignored if `lke_acl_enabled = false`. | `list(string)` | `[]` | no |
| <a name="input_lke_acl_ipv6"></a> [lke\_acl\_ipv6](#input\_lke\_acl\_ipv6) | IPv6 CIDRs to allow through the LKE control-plane ACL. Ignored if `lke_acl_enabled = false`. | `list(string)` | `[]` | no |
| <a name="input_longhorn_enabled"></a> [longhorn\_enabled](#input\_longhorn\_enabled) | Whether Longhorn should be installed | `bool` | `false` | no |
| <a name="input_mc_router_enabled"></a> [mc\_router\_enabled](#input\_mc\_router\_enabled) | When true, deploy `modules/mc_router` (a single LoadBalancer that routes<br/>all minecraft traffic by handshake hostname) and force every entry in<br/>`var.minecraft` to `service_type = ClusterIP`. Consolidates N per-server<br/>NodeBalancers down to one. Requires clients to keep dialing the same<br/>per-server hostnames. | `bool` | `false` | no |
| <a name="input_mc_router_proxy_protocol"></a> [mc\_router\_proxy\_protocol](#input\_mc\_router\_proxy\_protocol) | Real client IPs at mc-router via PROXY protocol: `off`, `accept` (mc-router accepts an optional header) or `on` (Envoy's TCPRoute, or mc-router's own NodeBalancer without a Gateway, also sends it). Roll out `accept` before `on`. With the Gateway, the IPs are only real once `gateway_proxy_protocol = "on"`. The minecraft servers themselves still see mc-router's pod IP. See modules/mc\_router. | `string` | `"off"` | no |
| <a name="input_triage_host"></a> [triage\_host](#input\_triage\_host) | hostname where triage party will reside | `string` | `""` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_lke_id"></a> [lke\_id](#output\_lke\_id) | n/a |
<!-- END_TF_DOCS -->