variable "ops" {
  description = <<-EOS
    Comma-separated Minecraft usernames granted op on this server. Names are
    resolved to UUIDs via Mojang/PlayerDB at container start; a stale (renamed
    or deleted) name will crash-loop the pod on next recreate. See README.md
    for how to check names and find current names for known UUIDs before
    running `terraform apply`.
  EOS
}

variable "motd" {
  description = "Message of the Day"
}

variable "hostname" {
  description = "DNS Hostname for the server"
}

variable "namespace" {
  default = "minecraft"
}

variable "port" {
  default = 25565
}

variable "chart_version" {
  type        = string
  description = "itzg/minecraft-server-charts chart version. Pin to what your running deployment expects; 4.x→5.x is a breaking upgrade."
  default     = "4.26.4"
}

variable "mc_version" {
  type        = string
  description = <<-EOS
    Minecraft server version passed to the itzg image (`minecraftServer.version`).
    Defaults to `LATEST`, which is what most users want. Pin to a specific version
    (e.g. `"1.21.8"`) when restoring a world from an older DataVersion — the itzg
    image runs the world's built-in upgrade on start, and skipping several majors
    at once has been observed to nuke the world during the upgrade cleanup step.
  EOS
  default     = "LATEST"
}

variable "claim" {
  type        = string
  description = <<-EOS
    Name of the PVC the module owns and passes to the chart via `existingClaim`.
    The module creates this PVC as a first-class terraform resource so a chart
    reinstall or version bump doesn't leave the previous PV `Released` and mint
    a new one. Default name preserves the historical PVC naming.
  EOS
  default     = "minecraft-minecraft-datadir"
}

variable "volume_name" {
  type        = string
  description = <<-EOS
    Optional pre-existing PersistentVolume to bind the PVC to (recovery /
    world-move workflow). Leave "" to dynamic-provision a fresh PV.
  EOS
  default     = ""
}

variable "storage_size" {
  type        = string
  description = "PVC size for the datadir."
  default     = "10Gi"
}

variable "storage_class" {
  type        = string
  description = "Storage class for the datadir PVC. `Retain` reclaim on this class is what makes recovery possible when things go sideways."
  default     = "linode-block-storage-retain"
}

variable "service_type" {
  type        = string
  description = <<-EOS
    Kubernetes Service type for the minecraft server. Default `LoadBalancer`
    provisions a dedicated Linode NodeBalancer per server. Set to `ClusterIP`
    when fronting the server via a shared entrypoint like `modules/mc_router`.
  EOS
  default     = "LoadBalancer"

  validation {
    condition     = contains(["LoadBalancer", "ClusterIP", "NodePort"], var.service_type)
    error_message = "service_type must be one of LoadBalancer, ClusterIP, NodePort."
  }
}
