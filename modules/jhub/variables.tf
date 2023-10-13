variable "hostname" {
}
variable "client_id" {}
variable "client_secret" {}
variable "gh_admin_users" {
  type        = list(string)
  description = "GitHub Admin Users"
}
