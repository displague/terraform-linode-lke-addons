variable "linode_token" { description = "Your Linode API Authentication Token." }
variable "issuer_email" { description = "An email address for ACME certificate registration." }
variable "example_host" { description = "If set, an ingress will be created with this hostname used. The domain should be one managed by your Linode account." }

variable "k8s_version" {
  description = "LKE K8s Version"
  default     = "1.26"
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
variable "minecraft_ops" {
  default     = ""
  description = "minecraft usernames that will receive ops"
}

variable "minecraft_motd" {
  default     = ""
  description = "Minecraft MOTD"
}

variable "minecraft_hostname" {
  default     = ""
  description = "hostname where minecraft will run"
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
