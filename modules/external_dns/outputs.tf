output "linode_api_token" {
  value     = linode_token.external_dns.token
  sensitive = true
}
