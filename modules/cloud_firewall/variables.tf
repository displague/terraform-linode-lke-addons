variable "chart_version" {
  type        = string
  default     = "0.2.1"
  description = "cloud-firewall-controller chart version. Upgrading applies the controller's latest default ruleset to the primary CloudFirewall (unless it was customised outside Helm)."
}

variable "crd_chart_version" {
  type        = string
  default     = "0.2.0"
  description = "cloud-firewall-crd chart version (the CloudFirewall CRD)."
}

variable "extra_inbound_rules" {
  type = list(object({
    label       = string
    action      = string
    description = optional(string)
    protocol    = string
    ports       = optional(string)
    addresses = object({
      ipv4 = optional(list(string))
      ipv6 = optional(list(string))
    })
  }))
  default     = []
  description = "Inbound rules appended to the controller's defaults, e.g. a port that must be reachable on every node. Most clusters need none: traffic should arrive through a NodeBalancer."
}
