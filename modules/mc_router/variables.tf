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

variable "share_nodebalancer_id" {
  type        = number
  default     = null
  description = <<-EOS
    Optional existing Linode NodeBalancer id to piggyback onto (typically
    the id of the NB fronting ingress-nginx). ccm-linode adds a port
    config for `external_port` to that NB instead of provisioning a
    dedicated one for mc-router. Ports across the consuming Services must
    not collide — mc-router on 25565 slots alongside ingress-nginx on
    80/443 without conflict.

    Also sets the `preserve` annotation so `helm uninstall mc-router`
    doesn't delete the shared NB (it belongs to the other Service).

    Uses ccm-linode's
    `service.beta.kubernetes.io/linode-loadbalancer-nodebalancer-id`
    annotation — see
    https://github.com/linode/linode-cloud-controller-manager/blob/main/docs/configuration/annotations.md
  EOS
}
