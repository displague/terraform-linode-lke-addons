variable "hostname" {
}
variable "client_id" {}
variable "client_secret" {}
variable "gh_admin_users" {
  type        = list(string)
  description = "GitHub Admin Users"
}
variable "hub_db_volume" { default = "" }

variable "proxy_service_type" {
  type        = string
  description = <<-EOS
    Kubernetes Service type for JupyterHub's `proxy-public`. The bundled
    chart defaults to `LoadBalancer`, which on Linode spins a dedicated
    NodeBalancer even though the module already wires up an
    ingress-nginx-backed Ingress on `var.hostname`. Setting this to
    `ClusterIP` drops the redundant NodeBalancer; traffic still reaches
    users via the shared ingress-nginx entrypoint.
  EOS
  default     = "ClusterIP"

  validation {
    condition     = contains(["LoadBalancer", "ClusterIP", "NodePort"], var.proxy_service_type)
    error_message = "proxy_service_type must be one of LoadBalancer, ClusterIP, NodePort."
  }
}
