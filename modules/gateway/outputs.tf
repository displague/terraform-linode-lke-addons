output "namespace" {
  value       = kubernetes_namespace.gateway.metadata[0].name
  description = "Namespace holding the Gateway."
}

output "gateway_name" {
  value       = var.gateway_name
  description = "Name of the Gateway resource."
}
