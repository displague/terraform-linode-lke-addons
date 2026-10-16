# cosi

Installs the [Linode COSI driver](https://github.com/linode/linode-cosi-driver)
(Container Object Storage Interface) so workloads can provision Linode Object
Storage buckets and S3 credentials declaratively with Kubernetes `BucketClaim`
and `BucketAccess` resources.

This module installs:

- Upstream COSI CRDs (`bucketclasses`, `bucketclaims`, `buckets`,
  `bucketaccessclasses`, `bucketaccesses` under `objectstorage.k8s.io/v1alpha1`)
  and `container-object-storage-controller` in
  `container-object-storage-system` (`v0.2.2`, from `assets/cosi-controller.yaml`).
- A Linode personal access token scoped to `object_storage:read_write` with
  `token_expiry`.
- The `linode-cosi-driver` Helm release in `namespace` (default
  `linode-cosi-driver`), which runs the driver and the COSI provisioner
  sidecar.
- Default cluster-scoped classes when `create_default_classes` is `true`
  (the default), using `region` (default `us-ord`):
  - `BucketClass/linode-objectstorage` (`deletionPolicy: Delete`)
  - `BucketClass/linode-objectstorage-retain` (`deletionPolicy: Retain`)
  - `BucketAccessClass/linode-objectstorage` (`read_write`)
  - `BucketAccessClass/linode-objectstorage-readonly` (`read_only`)
- Any additional or overriding classes passed in `bucket_classes` and
  `bucket_access_classes`.

### Claiming a bucket

Create a `BucketClaim` and a `BucketAccess` in the workload's namespace:

```yaml
apiVersion: objectstorage.k8s.io/v1alpha1
kind: BucketClaim
metadata:
  name: example
spec:
  bucketClassName: linode-objectstorage
  protocols: [S3]
---
apiVersion: objectstorage.k8s.io/v1alpha1
kind: BucketAccess
metadata:
  name: example
spec:
  bucketClaimName: example
  bucketAccessClassName: linode-objectstorage
  protocol: S3
  credentialsSecretName: example-bucket-credentials
```

The sidecar writes a `BucketInfo` JSON document into the Secret named by
`credentialsSecretName` (`spec.secretS3.endpoint`, `spec.secretS3.region`,
`spec.secretS3.accessKeyID`, `spec.secretS3.accessSecretKey`, and
`spec.bucketName`).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.6 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 3.0.0 |
| <a name="requirement_kubectl"></a> [kubectl](#requirement\_kubectl) | >= 1.19.0 |
| <a name="requirement_linode"></a> [linode](#requirement\_linode) | ~> 4.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_helm"></a> [helm](#provider\_helm) | >= 3.0.0 |
| <a name="provider_kubectl"></a> [kubectl](#provider\_kubectl) | >= 1.19.0 |
| <a name="provider_linode"></a> [linode](#provider\_linode) | ~> 4.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [helm_release.linode_cosi_driver](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubectl_manifest.bucket_access_class](https://registry.terraform.io/providers/gavinbunney/kubectl/latest/docs/resources/manifest) | resource |
| [kubectl_manifest.bucket_class](https://registry.terraform.io/providers/gavinbunney/kubectl/latest/docs/resources/manifest) | resource |
| [kubectl_manifest.cosi_controller](https://registry.terraform.io/providers/gavinbunney/kubectl/latest/docs/resources/manifest) | resource |
| [linode_token.cosi](https://registry.terraform.io/providers/linode/linode/latest/docs/resources/token) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_token_expiry"></a> [token\_expiry](#input\_token\_expiry) | Expiry date for the Linode API token used by linode-cosi-driver (`object_storage:read_write`). RFC3339 format. | `string` | n/a | yes |
| <a name="input_bucket_access_classes"></a> [bucket\_access\_classes](#input\_bucket\_access\_classes) | Additional BucketAccessClasses keyed by name (`objectstorage.k8s.io/v1alpha1`). Entries with the same name as a default BucketAccessClass override it. | <pre>map(object({<br/>    permissions              = optional(string, "read_write")<br/>    authentication_type      = optional(string, "Key")<br/>    endpoint_type            = optional(string)<br/>    endpoint_type_preference = optional(string)<br/>  }))</pre> | `{}` | no |
| <a name="input_bucket_classes"></a> [bucket\_classes](#input\_bucket\_classes) | Additional BucketClasses keyed by name (`objectstorage.k8s.io/v1alpha1`). Entries with the same name as a default BucketClass override it. | <pre>map(object({<br/>    region                   = string<br/>    deletion_policy          = optional(string, "Delete")<br/>    acl                      = optional(string, "private")<br/>    cors                     = optional(string, "disabled")<br/>    cleanup                  = optional(string)<br/>    endpoint_type            = optional(string)<br/>    endpoint_type_preference = optional(string)<br/>    policy                   = optional(string)<br/>  }))</pre> | `{}` | no |
| <a name="input_chart_version"></a> [chart\_version](#input\_chart\_version) | linode-cosi-driver Helm chart version. | `string` | `"0.9.5"` | no |
| <a name="input_create_default_classes"></a> [create\_default\_classes](#input\_create\_default\_classes) | Create default `linode-objectstorage` (deletionPolicy: Delete) and `linode-objectstorage-retain` (deletionPolicy: Retain) BucketClasses, plus the `linode-objectstorage` (read\_write) and `linode-objectstorage-readonly` (read\_only) BucketAccessClasses. | `bool` | `true` | no |
| <a name="input_image_pull_secrets"></a> [image\_pull\_secrets](#input\_image\_pull\_secrets) | Docker registry pull Secret names in `namespace` for the driver Deployment (`docker.io/linode/linode-cosi-driver`). | `list(string)` | `[]` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Namespace to install linode-cosi-driver into. | `string` | `"linode-cosi-driver"` | no |
| <a name="input_region"></a> [region](#input\_region) | Default Linode Object Storage region (`cosi.linode.com/v1/region`) on the default BucketClasses when `create_default_classes` is true. | `string` | `"us-ord"` | no |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
