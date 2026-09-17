variable "gh_token" {
  type = string
}
variable "triage_host" {
  type = string
}

variable "create_ingress" {
  type        = bool
  default     = true
  description = "Apply the Ingress asset for `triage_host`. Leave false (the default via the root module) when the host is routed by modules/gateway (an HTTPRoute); only useful with a bring-your-own ingress controller."
}
