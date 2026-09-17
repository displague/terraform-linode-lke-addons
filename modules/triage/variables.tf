variable "gh_token" {}
variable "triage_host" {}

variable "create_ingress" {
  type        = bool
  default     = true
  description = "Apply the nginx Ingress asset for `triage_host`. Set false when the host is routed by modules/gateway (an HTTPRoute) instead."
}
