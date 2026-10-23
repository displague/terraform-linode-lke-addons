# github_runners

Self-hosted GitHub Actions runners on the cluster, using GitHub's
[Actions Runner Controller](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners-with-actions-runner-controller)
(runner scale sets). Each job gets a fresh pod with Docker in a dind
sidecar; with `min_runners = 0` no pod runs while nothing is queued.

```hcl
module "github_runners" {
  source       = "./modules/github_runners"
  github_token = var.github_runner_token
  scale_sets = {
    lke = { config_url = "https://github.com/example/app", max_runners = 2 }
  }
}
```

Then in the repository's workflows: `runs-on: lke`.

Keep cluster-management pipelines (for example terraform applies against
this cluster) on GitHub-hosted runners, and use these only for private
repositories: on a public one, any fork pull request runs code here.

## Security

Runner pods run Docker in a **privileged** dind sidecar. A job that can run
`docker` can get root on the node it runs on, so these runners are only as
isolated as their node: on nodes shared with other workloads, treat every
job as able to reach whatever that node can (its other pods' volumes and
Secrets, the kubelet's credentials). The module narrows what a job can do
without escaping:

- **Network policy** (`network_policy`, on by default). Runner pods accept no
  inbound connections; nothing needs them, since runners poll GitHub and
  the ARC controller and listeners only use the Kubernetes and GitHub APIs.
  Outbound, they reach cluster DNS (port 53 in `kube-system`), the image
  cache when enabled, and the public internet, but no private or link-local
  address (`private_cidrs`): no other pods, Services, private node
  addresses or cloud metadata. Jobs and service containers run inside dind,
  NATed onto the pod's network, so the pod's policy covers them. Addresses
  that answer publicly, such as the nodes' public IPs (NodePorts, kubelet)
  or the Kubernetes API endpoint, stay reachable unless listed in
  `blocked_cidrs`. The image cache gets its own policy: pulls from runner
  pods in, DNS and the internet out. This needs a CNI that enforces
  NetworkPolicy (Calico does) and covers IPv4 only.
- **No ServiceAccount token** (`automount_service_account_token = false`).
  In dind mode the runner registers with a just-in-time config from a
  Secret and never calls the Kubernetes API, so jobs get no credentials
  for it.
- **Pod Security Admission** (`pod_security`). The runners namespace is
  labeled `warn` and `audit` at `baseline`, so privileged pods are flagged
  rather than silently accepted. `enforce` can't be `baseline` while the
  dind sidecar is privileged (or the toolchain cache, a hostPath, is on).

What this doesn't do: stop a container escape through the privileged
sidecar, isolate jobs that share a node, or keep a job from writing to the
toolchain cache that later jobs on the node read. Dedicated, tainted nodes
for runners contain an escape to those nodes. The path to enforcing
`baseline` is ARC's `containerMode` kubernetes (job containers as separate,
unprivileged pods) with rootless BuildKit for image builds instead of
Docker; this module doesn't offer that mode yet.

Rolling out: the policy only allows what the module's own pods need. A job
that talks to something private (a database in the cluster, a private
registry, a host on the VPC) fails once it applies; allow such
destinations in a separate NetworkPolicy, or set `network_policy.enabled =
false` while you find them.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.6 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 3.0.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.38.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_helm"></a> [helm](#provider\_helm) | >= 3.0.0 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | >= 2.38.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [helm_release.controller](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.scale_set](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubernetes_deployment_v1.image_cache](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/deployment_v1) | resource |
| [kubernetes_namespace_v1.controller](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace_v1) | resource |
| [kubernetes_namespace_v1.runners](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace_v1) | resource |
| [kubernetes_network_policy_v1.image_cache](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/network_policy_v1) | resource |
| [kubernetes_network_policy_v1.runners](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/network_policy_v1) | resource |
| [kubernetes_persistent_volume_claim_v1.image_cache](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/persistent_volume_claim_v1) | resource |
| [kubernetes_secret_v1.github](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret_v1) | resource |
| [kubernetes_secret_v1.image_cache_upstream](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret_v1) | resource |
| [kubernetes_service_v1.image_cache](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service_v1) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_scale_sets"></a> [scale\_sets](#input\_scale\_sets) | Runner scale sets, keyed by name; workflows select one with<br/>`runs-on: <name>`. `config_url` is the repository<br/>(`https://github.com/<owner>/<repo>`) or organization the runners<br/>register with; on a personal account, runners are per repository.<br/>`min_runners = 0` starts a pod only when a job is queued. | <pre>map(object({<br/>    config_url     = string<br/>    min_runners    = optional(number, 0)<br/>    max_runners    = optional(number, 2)<br/>    cpu_request    = optional(string, "500m")<br/>    memory_request = optional(string, "1Gi")<br/>    memory_limit   = optional(string, "3Gi")<br/>  }))</pre> | n/a | yes |
| <a name="input_automount_service_account_token"></a> [automount\_service\_account\_token](#input\_automount\_service\_account\_token) | Mount a ServiceAccount token into runner pods. Runners in dind mode don't use the Kubernetes API, so this stays off unless a job needs one. | `bool` | `false` | no |
| <a name="input_chart_version"></a> [chart\_version](#input\_chart\_version) | Version of both ARC charts (controller and scale set), which must match. | `string` | `"0.15.0"` | no |
| <a name="input_controller_namespace"></a> [controller\_namespace](#input\_controller\_namespace) | n/a | `string` | `"arc-systems"` | no |
| <a name="input_github_app"></a> [github\_app](#input\_github\_app) | GitHub App credentials, preferred over a token. The app needs Administration read/write on the repositories. | <pre>object({<br/>    app_id          = string<br/>    installation_id = string<br/>    private_key     = string<br/>  })</pre> | `null` | no |
| <a name="input_github_token"></a> [github\_token](#input\_github\_token) | Fine-grained personal access token with Administration read/write on each repository. Ignored when `github_app` is set. | `string` | `null` | no |
| <a name="input_image_cache"></a> [image\_cache](#input\_image\_cache) | A pull-through Docker Hub cache for the runners' Docker daemons: a<br/>`registry` in proxy mode on a persistent volume (block storage, one<br/>replica), set as each runner's `--registry-mirror`. The first job pulls<br/>an image from Docker Hub; later jobs get it from the cluster. Mirrors<br/>only apply to Docker Hub images (docker.io/...). | <pre>object({<br/>    enabled       = optional(bool, false)<br/>    size          = optional(string, "20Gi")<br/>    storage_class = optional(string)<br/>    image         = optional(string, "registry:2.8.3")<br/>    ttl           = optional(string, "168h")<br/>  })</pre> | `{}` | no |
| <a name="input_image_cache_upstream_credentials"></a> [image\_cache\_upstream\_credentials](#input\_image\_cache\_upstream\_credentials) | Docker Hub credentials for the cache's upstream pulls (avoids anonymous rate limits). | <pre>object({<br/>    username = string<br/>    password = string<br/>  })</pre> | `null` | no |
| <a name="input_image_pull_secrets"></a> [image\_pull\_secrets](#input\_image\_pull\_secrets) | Secrets in the runners namespace for pulling the runner and docker:dind images (for example Docker Hub credentials). | `list(string)` | `[]` | no |
| <a name="input_network_policy"></a> [network\_policy](#input\_network\_policy) | NetworkPolicies for the runners namespace (the cluster's CNI must<br/>enforce them, as Calico does). Runner pods accept no inbound traffic;<br/>outbound they reach cluster DNS, the image cache and any IPv4 address<br/>outside `private_cidrs` and `blocked_cidrs`. `private_cidrs` (RFC 1918,<br/>CGNAT, link-local) covers pod, Service and private node networks and<br/>cloud metadata; add anything that answers on a public address, such as<br/>the nodes' public IPs or the Kubernetes API endpoint, to `blocked_cidrs`. | <pre>object({<br/>    enabled = optional(bool, true)<br/>    private_cidrs = optional(list(string), [<br/>      "10.0.0.0/8",<br/>      "172.16.0.0/12",<br/>      "192.168.0.0/16",<br/>      "100.64.0.0/10",<br/>      "169.254.0.0/16",<br/>    ])<br/>    blocked_cidrs = optional(list(string), [])<br/>  })</pre> | `{}` | no |
| <a name="input_pod_security"></a> [pod\_security](#input\_pod\_security) | Pod Security Admission levels (`privileged`, `baseline`, `restricted`)<br/>for the runners namespace; `null` leaves a mode unset. The dind sidecar<br/>is privileged, so `enforce` can be at most `privileged` here; enforcing<br/>`baseline` needs runners without dind (`containerMode` kubernetes). | <pre>object({<br/>    enforce = optional(string)<br/>    warn    = optional(string, "baseline")<br/>    audit   = optional(string, "baseline")<br/>  })</pre> | `{}` | no |
| <a name="input_runner_image"></a> [runner\_image](#input\_runner\_image) | Runner image. GitHub rejects runners more than 30 days behind the latest release, so `latest` is the usual choice. | `string` | `"ghcr.io/actions/actions-runner:latest"` | no |
| <a name="input_runners_namespace"></a> [runners\_namespace](#input\_runners\_namespace) | n/a | `string` | `"arc-runners"` | no |
| <a name="input_toolchain_cache"></a> [toolchain\_cache](#input\_toolchain\_cache) | A per-node cache directory (hostPath) mounted into every runner pod for<br/>toolchains that jobs otherwise download each time: uv's package cache<br/>and Python installs, Playwright browsers, npm's cache and the Actions<br/>tool cache (setup-node, setup-uv). These tools lock their caches, so<br/>concurrent jobs on a node are safe; a replaced node starts cold. Jobs can<br/>write to it, so a job could poison it for later jobs on that node: use<br/>it only for trusted (private) repositories. | <pre>object({<br/>    enabled   = optional(bool, false)<br/>    host_path = optional(string, "/var/cache/github-runners")<br/>  })</pre> | `{}` | no |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
