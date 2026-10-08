# cloud_firewall

Installs Linode's [cloud-firewall-controller](https://github.com/linode/cloud-firewall-controller),
which attaches one Cloud Firewall to every node in the cluster, including
nodes created later by upgrades or the autoscaler.

The default ruleset drops inbound traffic except from the LKE control plane
and nodes (`192.168.128.0/17`) and from NodeBalancers on the NodePort range
(`192.168.255.0/24`). Without it, NodePorts are reachable from the internet,
so anything behind a LoadBalancer Service can be reached directly, bypassing
the NodeBalancer. That's also a prerequisite for trusting PROXY protocol
headers at the gateway.

The controller uses the API token LKE already provides to the cloud
controller manager (`kube-system/linode`); no new credential is needed.

Removing the module uninstalls the controller. Check Cloud Manager afterwards
for the firewall it managed, and detach or delete it if you no longer want
it.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.6 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 3.0.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_helm"></a> [helm](#provider\_helm) | >= 3.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [helm_release.controller](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.crd](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_chart_version"></a> [chart\_version](#input\_chart\_version) | cloud-firewall-controller chart version. Upgrading applies the controller's latest default ruleset to the primary CloudFirewall (unless it was customised outside Helm). | `string` | `"0.2.1"` | no |
| <a name="input_crd_chart_version"></a> [crd\_chart\_version](#input\_crd\_chart\_version) | cloud-firewall-crd chart version (the CloudFirewall CRD). | `string` | `"0.2.0"` | no |
| <a name="input_extra_inbound_rules"></a> [extra\_inbound\_rules](#input\_extra\_inbound\_rules) | Inbound rules appended to the controller's defaults, e.g. a port that must be reachable on every node. Most clusters need none: traffic should arrive through a NodeBalancer. | <pre>list(object({<br/>    label       = string<br/>    action      = string<br/>    description = optional(string)<br/>    protocol    = string<br/>    ports       = optional(string)<br/>    addresses = object({<br/>      ipv4 = optional(list(string))<br/>      ipv6 = optional(list(string))<br/>    })<br/>  }))</pre> | `[]` | no |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
