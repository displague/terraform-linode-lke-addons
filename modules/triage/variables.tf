variable "gh_token" {
  type = string
}
variable "triage_host" {
  type = string
}

variable "namespace" {
  type        = string
  default     = "triage"
  description = "Namespace for Triage Party."
}

variable "name" {
  type        = string
  default     = "Triage"
  description = "Display name Triage Party shows for this site."
}

variable "repos" {
  type        = list(string)
  description = "GitHub repositories to triage, as https://github.com/org/repo URLs."

  validation {
    condition     = length(var.repos) > 0
    error_message = "Pass at least one GitHub repository URL in repos."
  }
}

variable "create_ingress" {
  type        = bool
  default     = true
  description = "Apply the Ingress asset for `triage_host`. Leave false (the default via the root module) when the host is routed by modules/gateway (an HTTPRoute); only useful with a bring-your-own ingress controller."
}
