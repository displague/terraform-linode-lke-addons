variable "linode_token" { description = "Your Linode API Authentication Token." }
variable "issuer_email" { description = "An email address for ACME certificate registration."}
variable "example_host" { description = "If set, an ingress will be created with this hostname used. The domain should be one managed by your Linode account." }
