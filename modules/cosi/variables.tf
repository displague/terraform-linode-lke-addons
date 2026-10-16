variable "token_expiry" {
  type        = string
  description = "Expiry date for the Linode API token used by linode-cosi-driver (`object_storage:read_write`). RFC3339 format."
}

variable "namespace" {
  type        = string
  default     = "linode-cosi-driver"
  description = "Namespace to install linode-cosi-driver into."
}

variable "chart_version" {
  type        = string
  default     = "0.9.5"
  description = "linode-cosi-driver Helm chart version."
}

variable "image_pull_secrets" {
  type        = list(string)
  default     = []
  description = "Docker registry pull Secret names in `namespace` for the driver Deployment (`docker.io/linode/linode-cosi-driver`)."
}

variable "create_default_classes" {
  type        = bool
  default     = true
  description = "Create default `linode-objectstorage` (deletionPolicy: Delete) and `linode-objectstorage-retain` (deletionPolicy: Retain) BucketClasses, plus the `linode-objectstorage` (read_write) and `linode-objectstorage-readonly` (read_only) BucketAccessClasses."
}

variable "region" {
  type        = string
  default     = "us-ord"
  description = "Default Linode Object Storage region (`cosi.linode.com/v1/region`) on the default BucketClasses when `create_default_classes` is true."
}

variable "bucket_classes" {
  type = map(object({
    region                   = string
    deletion_policy          = optional(string, "Delete")
    acl                      = optional(string, "private")
    cors                     = optional(string, "disabled")
    cleanup                  = optional(string)
    endpoint_type            = optional(string)
    endpoint_type_preference = optional(string)
    policy                   = optional(string)
  }))
  default     = {}
  description = "Additional BucketClasses keyed by name (`objectstorage.k8s.io/v1alpha1`). Entries with the same name as a default BucketClass override it."

  validation {
    condition     = alltrue([for c in values(var.bucket_classes) : contains(["Delete", "Retain"], c.deletion_policy)])
    error_message = "bucket_classes deletion_policy must be \"Delete\" or \"Retain\"."
  }
}

variable "bucket_access_classes" {
  type = map(object({
    permissions              = optional(string, "read_write")
    authentication_type      = optional(string, "Key")
    endpoint_type            = optional(string)
    endpoint_type_preference = optional(string)
  }))
  default     = {}
  description = "Additional BucketAccessClasses keyed by name (`objectstorage.k8s.io/v1alpha1`). Entries with the same name as a default BucketAccessClass override it."

  validation {
    condition     = alltrue([for c in values(var.bucket_access_classes) : contains(["read_only", "read_write"], c.permissions)])
    error_message = "bucket_access_classes permissions must be \"read_only\" or \"read_write\"."
  }
}
