variable "ops" {
  description = "Admin accounts for minecraft server. These account names must be valid."
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

variable "claim" {
  type        = string
  description = <<-EOS
    Existing claim to reuse. Between reuses be sure to clear the claimRef of the Released pv. `kubectl patch pv $PV_NAME -p '{"spec":{"claimRef": null}}'`
  EOS
  default     = ""
}
