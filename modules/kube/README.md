<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.6 |
| <a name="requirement_linode"></a> [linode](#requirement\_linode) | ~> 4.0 |
| <a name="requirement_local"></a> [local](#requirement\_local) | >= 2.5.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_linode"></a> [linode](#provider\_linode) | 1.20.2 |
| <a name="provider_local"></a> [local](#provider\_local) | 2.1.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [linode_lke_cluster.lke](https://registry.terraform.io/providers/linode/linode/latest/docs/resources/lke_cluster) | resource |
| [local_file.lke_config](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_lke_config"></a> [lke\_config](#input\_lke\_config) | n/a | `string` | n/a | yes |
| <a name="input_control_plane_acl"></a> [control\_plane\_acl](#input\_control\_plane\_acl) | Optional control-plane ACL configuration. Leave `null` to *not* manage<br>the ACL from terraform (recommended if you're setting it via the<br>Cloud UI or the Linode API directly).<br><br>When non-null:<br>- `enabled = true` locks the API to the given ipv4/ipv6 lists. An empty<br>  allow list with `enabled = true` blackholes the API — Linode's 2025<br>  rollout defaulted many accounts into exactly this state, so if you<br>  opt in here, always pass at least one CIDR.<br>- `enabled = false` explicitly removes any existing ACL (open access).<br><br>See docs: https://techdocs.akamai.com/cloud-computing/docs/control-plane-acls | <pre>object({<br>    enabled = bool<br>    ipv4    = optional(list(string), [])<br>    ipv6    = optional(list(string), [])<br>  })</pre> | `null` | no |
| <a name="input_k8s_version"></a> [k8s\_version](#input\_k8s\_version) | n/a | `string` | `"1.36"` | no |
| <a name="input_max_count"></a> [max\_count](#input\_max\_count) | n/a | `number` | `3` | no |
| <a name="input_min_count"></a> [min\_count](#input\_min\_count) | n/a | `number` | `1` | no |
| <a name="input_pool_disk_encryption"></a> [pool\_disk\_encryption](#input\_pool\_disk\_encryption) | Local disk encryption at rest on the node pool. `"enabled"` or<br>`"disabled"`.<br><br>Fresh-pool-only: the Linode API rejects updates to this on an existing<br>pool. To turn encryption on for a running cluster you need to add a new<br>pool with `disk_encryption = "enabled"`, drain workloads onto it, and<br>delete the old pool. See<br>https://techdocs.akamai.com/cloud-computing/docs/local-disk-encryption | `string` | `null` | no |
| <a name="input_pool_firewall_id"></a> [pool\_firewall\_id](#input\_pool\_firewall\_id) | Cloud Firewall to attach to the node pool. Pass the id of a<br>`linode_firewall` resource. Editable on a live pool — `terraform apply`<br>attaches / detaches without a node cycle. Free of charge on Linode. | `number` | `null` | no |
| <a name="input_stack_type"></a> [stack\_type](#input\_stack\_type) | Cluster IP stack. `"ipv4"` (default, single-stack) or `"dual"` (dual-stack<br>v4+v6). Leaving `null` matches the pre-feature LKE behavior.<br><br>Fresh-cluster-only: verified against the API that `stack_type` is not<br>editable on an existing cluster. Only meaningful when this module is<br>provisioning a new cluster. | `string` | `null` | no |
| <a name="input_subnet_id"></a> [subnet\_id](#input\_subnet\_id) | Linode VPC subnet the cluster's nodes attach to. Pairs with `vpc_id`.<br>Fresh-cluster-only (see `vpc_id`). | `number` | `null` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | Linode VPC to place the cluster in. Requires `subnet_id` alongside.<br>Fresh-cluster-only: moving an existing cluster onto a VPC would require<br>recreate. Use with the `linode_vpc` / `linode_vpc_subnet` resources. | `number` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_lke_config"></a> [lke\_config](#output\_lke\_config) | n/a |
| <a name="output_lke_id"></a> [lke\_id](#output\_lke\_id) | ID of the Linode LKE Cluster created |
<!-- END_TF_DOCS -->