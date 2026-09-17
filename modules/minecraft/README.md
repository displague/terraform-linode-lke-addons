## Minecraft server module

Wraps the `itzg/minecraft-server-charts` Helm chart with a Linode-friendly default
(LoadBalancer service + block-storage PVC) and takes ops/motd/hostname/claim inputs.

### PVC ownership

The module creates its own `kubernetes_persistent_volume_claim` and passes its
name to the chart as `persistence.dataDir.existingClaim`. Terraform, not the
Helm chart, is the source of truth for the PVC's identity — that way a
`helm uninstall` or a chart-version bump doesn't leave the PV `Released` and
mint a new one on the next `terraform apply` (which is how orphan PVs have
accumulated on this cluster historically).

Inputs:
- `claim` — name of the PVC. Defaults to `"minecraft-minecraft-datadir"`, the
  historical chart-generated name.
- `volume_name` — optional pre-existing PV to bind. Set this when restoring a
  world from a `Retain`-preserved PV. Leave empty for dynamic provisioning.
- `storage_size` (default `"10Gi"`), `storage_class` (default
  `"linode-block-storage-retain"`).

#### Migrating an existing chart-managed PVC

If your cluster already has a chart-managed PVC for a running minecraft
release, `terraform apply` after upgrading this module will fail because the
PVC already exists and isn't in state. Import it first, per instance:

```sh
terraform import 'module.minecraft[0].kubernetes_namespace.minecraft' minecraft
terraform import 'module.minecraft[0].kubernetes_persistent_volume_claim.datadir' minecraft/minecraft-minecraft-datadir
```

Repeat for each element of the `minecraft` list. After the import terraform
will see the PVC and simply own it going forward.

### Watch out: `ops` and Minecraft username renames

The `ops` input is a comma-separated list of **current** Minecraft usernames. On
container start the [itzg image](https://github.com/itzg/docker-minecraft-server)
resolves each name to a UUID via Mojang / PlayerDB. If a listed name no longer
resolves (the player renamed, or the account was deleted), the container fails
the `manage-users` step and the pod enters `CrashLoopBackOff`.

Symptom in pod logs:

```
[mc-image-helper] ERROR : Invalid parameter provided for 'manage-users' command:
Could not resolve user from Playerdb: <name>
```

Existing pods keep running because `/data/ops.json` already caches the UUID; the
failure surfaces on the next helm re-apply / pod recreate (upgrade, node cycle,
version bump, or `tfvars` change).

**How to check whether an ops entry is still valid:**

```sh
NAME=<username>
curl -sS "https://api.mojang.com/users/profiles/minecraft/$NAME"
# 200 with an "id" field → still valid
# {"errorMessage":"Couldn't find any profile ..."} → renamed or deleted
```

**How to find the current name for a UUID you already have in `ops.json`:**

```sh
UUID=<32-char-uuid-without-dashes>
curl -sS "https://sessionserver.mojang.com/session/minecraft/profile/$UUID"
# returns {"id":"…","name":"CurrentName", ...}
```

Run it against any UUIDs pulled from `kubectl -n <ns> exec deploy/minecraft -- cat /data/ops.json`.

**When to check:** before any operation that could recreate a pod (LKE upgrade,
`terraform apply` on the minecraft module, node recycle, chart bump). Fix stale
names in `terraform.tfvars` **before** the apply, or the pod will crash-loop on
the next start.

**If a pod is already crash-looping on a stale name:** the running `ops.json` on
the PV is preserved (`Retain` policy on the block volume), so you can either
(a) update `tfvars` to the current name and reapply, or (b) as an emergency
patch, edit the Deployment env `OPS` inline (`kubectl -n <ns> edit deploy
minecraft`) — but helm will overwrite that on the next terraform apply.

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
| [helm_release.minecraft](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubernetes_namespace.minecraft](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) | resource |
| [kubernetes_persistent_volume_claim.datadir](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/persistent_volume_claim) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_hostname"></a> [hostname](#input\_hostname) | DNS Hostname for the server | `string` | n/a | yes |
| <a name="input_motd"></a> [motd](#input\_motd) | Message of the Day | `string` | n/a | yes |
| <a name="input_ops"></a> [ops](#input\_ops) | Comma-separated Minecraft usernames granted op on this server. Names are<br/>resolved to UUIDs via Mojang/PlayerDB at container start; a stale (renamed<br/>or deleted) name will crash-loop the pod on next recreate. See README.md<br/>for how to check names and find current names for known UUIDs before<br/>running `terraform apply`. | `string` | n/a | yes |
| <a name="input_chart_version"></a> [chart\_version](#input\_chart\_version) | itzg/minecraft-server-charts chart version. Pin to what your running deployment expects; 4.x→5.x is a breaking upgrade. | `string` | `"4.26.4"` | no |
| <a name="input_claim"></a> [claim](#input\_claim) | Name of the PVC the module owns and passes to the chart via `existingClaim`.<br/>The module creates this PVC as a first-class terraform resource so a chart<br/>reinstall or version bump doesn't leave the previous PV `Released` and mint<br/>a new one. Default name preserves the historical PVC naming. | `string` | `"minecraft-minecraft-datadir"` | no |
| <a name="input_mc_version"></a> [mc\_version](#input\_mc\_version) | Minecraft server version passed to the itzg image (`minecraftServer.version`).<br/>Defaults to `LATEST`, which is what most users want. Pin to a specific version<br/>(e.g. `"1.21.8"`) when restoring a world from an older DataVersion — the itzg<br/>image runs the world's built-in upgrade on start, and skipping several majors<br/>at once has been observed to nuke the world during the upgrade cleanup step. | `string` | `"LATEST"` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | n/a | `string` | `"minecraft"` | no |
| <a name="input_port"></a> [port](#input\_port) | n/a | `number` | `25565` | no |
| <a name="input_service_type"></a> [service\_type](#input\_service\_type) | Kubernetes Service type for the minecraft server. Default `LoadBalancer`<br/>provisions a dedicated Linode NodeBalancer per server. Set to `ClusterIP`<br/>when fronting the server via a shared entrypoint like `modules/mc_router`. | `string` | `"LoadBalancer"` | no |
| <a name="input_storage_class"></a> [storage\_class](#input\_storage\_class) | Storage class for the datadir PVC. `Retain` reclaim on this class is what makes recovery possible when things go sideways. | `string` | `"linode-block-storage-retain"` | no |
| <a name="input_storage_size"></a> [storage\_size](#input\_storage\_size) | PVC size for the datadir. | `string` | `"10Gi"` | no |
| <a name="input_volume_name"></a> [volume\_name](#input\_volume\_name) | Optional pre-existing PersistentVolume to bind the PVC to (recovery /<br/>world-move workflow). Leave "" to dynamic-provision a fresh PV. | `string` | `""` | no |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
