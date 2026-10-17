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
