locals {
  # "ingress" stays last so toggling it never shifts the other indices.
  names = concat([
    "ns",
    "secret",
    "configmap",
    "deployment",
    "service",
  ], var.create_ingress ? ["ingress"] : [])
}

resource "kubectl_manifest" "triage" {
  count = length(local.names)
  yaml_body = templatefile("${path.module}/assets/triage-${local.names[count.index]}.yaml", {
    gh_token    = var.gh_token
    triage_host = var.triage_host
    namespace   = var.namespace
    name        = var.name
    repos       = var.repos
  })
  validate_schema = false
}

moved {
  from = kubectl_manifest.triage_tinkerbell
  to   = kubectl_manifest.triage
}
