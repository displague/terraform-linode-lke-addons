locals {
  names = [
    "ns",
    "secret",
    "party-tinkerbell/configmap-tinkerbell",
    "deployment",
    "service",
    "ingress",
  ]
}
resource "kubectl_manifest" "triage_tinkerbell" {
  count = length(local.names)
  yaml_body = templatefile("${path.module}/assets/triage-${local.names[count.index]}.yaml", {
    gh_token    = var.gh_token
    triage_host = var.triage_host
  })
  validate_schema = false
}
