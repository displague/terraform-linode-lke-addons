variable "username" {
  type        = string
  description = "Docker Hub username that owns the access token."
}

variable "token" {
  type        = string
  sensitive   = true
  description = "Docker Hub personal access token, read-only on public repositories is enough."
}

variable "namespaces" {
  type        = list(string)
  description = "Namespaces that get the pull Secret."
}

variable "default_service_account_namespaces" {
  type        = list(string)
  description = "Subset of `namespaces` whose `default` ServiceAccount should use the Secret (pods that don't name their own ServiceAccount)."
  default     = []
}

variable "secret_name" {
  type        = string
  description = "Name of the pull Secret in each namespace."
  default     = "dockerhub"
}
