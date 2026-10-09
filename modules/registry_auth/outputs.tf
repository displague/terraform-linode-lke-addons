output "secret_name" {
  value       = var.secret_name
  description = "Name of the pull Secret, for charts that take `imagePullSecrets`."
}
