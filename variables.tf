variable "linode_token" { description = "Your Linode API Authentication Token." }
variable "issuer_email" { description = "An email address for ACME certificate registration." }
variable "example_host" { description = "If set, an ingress will be created with this hostname used. The domain should be one managed by your Linode account." }
variable "gh_token" {
  default     = ""
  description = "GH token for triage party"
  sensitive   = true
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
