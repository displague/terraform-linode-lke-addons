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
    Existing claim to reuse. Between reuses be sure to clear the claimRef of the Released pv. `kubectl patch pv $PV_NAME -p '{"spec":{"claimRef": null}}'`
  EOS
  default     = ""
}
