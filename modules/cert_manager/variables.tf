variable "issuer_email" {
  type = string
}
variable "linode_api_token" {
  type      = string
  sensitive = true
}

variable "gateway_api_enabled" {
  type        = bool
  default     = false
  description = "Enable cert-manager's Gateway API support (`config.gatewayAPI.enabled`): Gateways annotated with `cert-manager.io/cluster-issuer` get a Certificate per HTTPS listener. Requires the Gateway API CRDs to exist before cert-manager starts."
}
