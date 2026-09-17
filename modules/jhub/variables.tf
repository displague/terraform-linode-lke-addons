variable "hostname" {
}
variable "client_id" {}
variable "client_secret" {}
variable "gh_admin_users" {
  type        = list(string)
  description = "GitHub Admin Users"
}

variable "hub_db_volume" {
  type        = string
  default     = ""
  description = <<-EOS
    Optional pre-existing PersistentVolume name to bind the hub sqlite PVC
    to. Set this when adopting the module for an existing chart-managed
    PVC (`Retain` policy preserves the PV across the migration). Leave ""
    to let the storage class dynamically provision a fresh PV.
  EOS
}

variable "hub_db_claim" {
  type        = string
  default     = "hub-db-dir"
  description = <<-EOS
    Name of the terraform-managed PVC that stores the hub sqlite database.
    Default matches the historical chart-generated name for zero-downtime
    migration from `hub.db.type = sqlite-pvc`.
  EOS
}

variable "hub_db_storage_size" {
  type        = string
  default     = "10Gi"
  description = "Size of the hub sqlite PVC. 10Gi is the historical chart default via linode-block-storage."
}

variable "hub_db_storage_class" {
  type        = string
  default     = "linode-block-storage-retain"
  description = "Storage class for the hub sqlite PVC. `Retain` reclaim is what makes recovery possible when things go sideways."
}

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
