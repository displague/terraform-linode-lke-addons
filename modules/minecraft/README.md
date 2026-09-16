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
