variable "external_dns_token_expiry" {
  description = "Expiry date for the Linode API token used by external-dns. RFC3339 format."
  type        = string
}

variable "sources" {
  type        = list(string)
  default     = ["service", "ingress"]
  description = "external-dns `--source` list. Use [\"gateway-httproute\", \"gateway-tcproute\"] once traffic is fronted by a Gateway API Gateway; the chart's ClusterRole already covers gateway.networking.k8s.io."
}
