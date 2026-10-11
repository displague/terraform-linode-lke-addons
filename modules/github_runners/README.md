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
| [kubernetes_persistent_volume_claim_v1.image_cache](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/persistent_volume_claim_v1) | resource |
| [kubernetes_secret_v1.github](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret_v1) | resource |
| [kubernetes_secret_v1.image_cache_upstream](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret_v1) | resource |
| [kubernetes_service_v1.image_cache](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service_v1) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_scale_sets"></a> [scale\_sets](#input\_scale\_sets) | Runner scale sets, keyed by name; workflows select one with<br/>`runs-on: <name>`. `config_url` is the repository<br/>(`https://github.com/<owner>/<repo>`) or organization the runners<br/>register with; on a personal account, runners are per repository.<br/>`min_runners = 0` starts a pod only when a job is queued. | <pre>map(object({<br/>    config_url     = string<br/>    min_runners    = optional(number, 0)<br/>    max_runners    = optional(number, 2)<br/>    cpu_request    = optional(string, "500m")<br/>    memory_request = optional(string, "1Gi")<br/>    memory_limit   = optional(string, "3Gi")<br/>  }))</pre> | n/a | yes |
| <a name="input_chart_version"></a> [chart\_version](#input\_chart\_version) | Version of both ARC charts (controller and scale set), which must match. | `string` | `"0.15.0"` | no |
| <a name="input_controller_namespace"></a> [controller\_namespace](#input\_controller\_namespace) | n/a | `string` | `"arc-systems"` | no |
| <a name="input_github_app"></a> [github\_app](#input\_github\_app) | GitHub App credentials, preferred over a token. The app needs Administration read/write on the repositories. | <pre>object({<br/>    app_id          = string<br/>    installation_id = string<br/>    private_key     = string<br/>  })</pre> | `null` | no |
| <a name="input_github_token"></a> [github\_token](#input\_github\_token) | Fine-grained personal access token with Administration read/write on each repository. Ignored when `github_app` is set. | `string` | `null` | no |
| <a name="input_image_cache"></a> [image\_cache](#input\_image\_cache) | A pull-through Docker Hub cache for the runners' Docker daemons: a<br/>`registry` in proxy mode on a persistent volume (block storage, one<br/>replica), set as each runner's `--registry-mirror`. The first job pulls<br/>an image from Docker Hub; later jobs get it from the cluster. Mirrors<br/>only apply to Docker Hub images (docker.io/...). | <pre>object({<br/>    enabled       = optional(bool, false)<br/>    size          = optional(string, "20Gi")<br/>    storage_class = optional(string)<br/>    image         = optional(string, "registry:2.8.3")<br/>    ttl           = optional(string, "168h")<br/>  })</pre> | `{}` | no |
| <a name="input_image_cache_upstream_credentials"></a> [image\_cache\_upstream\_credentials](#input\_image\_cache\_upstream\_credentials) | Docker Hub credentials for the cache's upstream pulls (avoids anonymous rate limits). | <pre>object({<br/>    username = string<br/>    password = string<br/>  })</pre> | `null` | no |
| <a name="input_image_pull_secrets"></a> [image\_pull\_secrets](#input\_image\_pull\_secrets) | Secrets in the runners namespace for pulling the runner and docker:dind images (for example Docker Hub credentials). | `list(string)` | `[]` | no |
| <a name="input_runner_image"></a> [runner\_image](#input\_runner\_image) | Runner image. GitHub rejects runners more than 30 days behind the latest release, so `latest` is the usual choice. | `string` | `"ghcr.io/actions/actions-runner:latest"` | no |
| <a name="input_runners_namespace"></a> [runners\_namespace](#input\_runners\_namespace) | n/a | `string` | `"arc-runners"` | no |
| <a name="input_toolchain_cache"></a> [toolchain\_cache](#input\_toolchain\_cache) | A per-node cache directory (hostPath) mounted into every runner pod for<br/>toolchains that jobs otherwise download each time: uv's package cache<br/>and Python installs, Playwright browsers, npm's cache and the Actions<br/>tool cache (setup-node, setup-uv). These tools lock their caches, so<br/>concurrent jobs on a node are safe; a replaced node starts cold. Jobs can<br/>write to it, so a job could poison it for later jobs on that node: use<br/>it only for trusted (private) repositories. | <pre>object({<br/>    enabled   = optional(bool, false)<br/>    host_path = optional(string, "/var/cache/github-runners")<br/>  })</pre> | `{}` | no |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
