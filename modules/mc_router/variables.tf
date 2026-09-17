variable "chart_version" {
  type        = string
  description = "itzg/mc-router chart version. Pinned so upstream changes don't silently roll out."
  default     = "1.5.0"
}

variable "namespace" {
  type        = string
  description = "Kubernetes namespace to install mc-router into."
  default     = "mc-router"
}

variable "mappings" {
  type = list(object({
    hostname = string # external hostname minecraft clients dial (e.g. "mc1.example.com")
    target   = string # k8s Service address:port (e.g. "minecraft.minecraft.svc.cluster.local:25565")
  }))
  description = <<-EOS
    Mapping list turned into `minecraftRouter.mappings` on the itzg/mc-router
    chart. Each entry routes an inbound Minecraft handshake for the given
    hostname to the matching in-cluster Service.
  EOS
}

variable "external_port" {
  type        = number
  description = "External Minecraft port exposed by the mc-router LoadBalancer Service."
  default     = 25565
}


variable "service_type" {
  type        = string
  default     = "LoadBalancer"
  description = "Service type for mc-router. `LoadBalancer` = its own NodeBalancer (external-dns hostnames published from the Service). `ClusterIP` = sit behind a Gateway API TCPRoute (modules/gateway), which then owns the hostnames."
  validation {
    condition     = contains(["LoadBalancer", "ClusterIP"], var.service_type)
    error_message = "service_type must be LoadBalancer or ClusterIP."
  }
}
