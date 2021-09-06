terraform {
  required_providers {
    linode = {
      source = "linode/linode"
      # version = "..."
    }
    kubectl = {
      source = "gavinbunney/kubectl"
    }
  }
}

