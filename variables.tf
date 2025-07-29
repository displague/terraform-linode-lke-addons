variable "external_dns_token_expiry" {
  description = "Expiry date for the Linode API token used by external-dns. RFC3339 format."
  type        = string
}
variable "linode_token" { description = "Your Linode API Authentication Token." }
variable "issuer_email" { description = "An email address for ACME certificate registration." }
variable "example_host" { description = "If set, an ingress will be created with this hostname used. The domain should be one managed by your Linode account." }

variable "k8s_version" {
  description = "LKE K8s Version"
  default     = "1.26"
}

variable "longhorn_enabled" {
  default     = false
  description = "Whether Longhorn should be installed"
}

variable "gh_token" {
  default     = ""
  description = "GH token for triage party"
  sensitive   = true
}
variable "gh_admin_users" {
  default     = []
  description = "GH admin_users for JupyterHub"
  type        = list(string)
}

variable "triage_host" {
  default     = ""
  description = "hostname where triage party will reside"
}

variable "minecraft" {
  type = list(object(
    {
      namespace = string
      port      = number
      ops       = string
      motd      = string
      hostname  = string
      claim     = string
    }
  ))
  description = <<-EOT
A list of minecraft servers to deploy. Each object should have the following fields:
- namespace: the namespace of the minecraft server
- port: the port to run the minecraft server on
- ops: a list of minecraft usernames that will receive ops
- motd: the minecraft MOTD
- hostname: the hostname where minecraft will run
- claim: existing claim
EOT
}

variable "jhub_hostname" {
  default     = ""
  description = "hostname for jupyter hub"
}

variable "jhub_client_id" {
  default     = ""
  description = "GH client_id for jhub"
}
variable "jhub_client_secret" {
  default     = ""
  description = "GH client_secret for jhub"
}
variable "jhub_db_volume" {
  default     = ""
  description = "PVC name for Hub DB Volume"
}
