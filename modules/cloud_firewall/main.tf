# Linode's cloud-firewall-controller: keeps every LKE node attached to one
# Cloud Firewall, including nodes created later by LKE upgrades or the
# autoscaler. Its default ruleset admits only the control plane and nodes
# (192.168.128.0/17: kubelet, WireGuard, Calico BGP/Typha/IP-in-IP, cluster
# DNS) and NodeBalancers on the NodePort range (192.168.255.0/24), and drops
# all other inbound traffic, so NodePorts can't be reached directly from the
# internet. It uses the Linode API token LKE already provides to the cloud
# controller manager (kube-system/linode), so no new credential is added.
#
# https://github.com/linode/cloud-firewall-controller

resource "helm_release" "crd" {
  name       = "cloud-firewall-crd"
  repository = "https://linode.github.io/cloud-firewall-controller"
  chart      = "cloud-firewall-crd"
  version    = var.crd_chart_version
  namespace  = "kube-system"
}

resource "helm_release" "controller" {
  depends_on = [helm_release.crd]
  name       = "cloud-firewall"
  repository = "https://linode.github.io/cloud-firewall-controller"
  chart      = "cloud-firewall-controller"
  version    = var.chart_version
  namespace  = "kube-system"

  # Extra inbound rules are appended to the controller's default ruleset.
  values = length(var.extra_inbound_rules) > 0 ? [yamlencode({
    firewall = { inbound = var.extra_inbound_rules }
  })] : []
}
