## LKE with Extras

This Terraform module provisions Linode Kubernetes Engine (LKE) with common add-ons:

- External DNS
  External DNS is configured with a Linode API token scoped to DNS services.
- Cert Manager
  cert-manager is configured with an HTTP prover (which uses nginx-ingress).
- Nginx Ingress Controller
  This default ingress controller will use a single LoadBalancer Service for all Ingress objects.
  The Ingress is configured with 0.2.1 of <https://github.com/compumike/hairpin-proxy#hairpin-proxy> which fixes problems with using the proxy protocol. (See the link for more details)

## Variables

See `terraform.tfvars.sample`. Copy this to `terraform.tfvars` and modify as needed.

## Install

```sh
terraform apply
```
