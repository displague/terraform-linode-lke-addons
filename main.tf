provider "linode" {
  token = var.linode_token
}

resource "linode_lke_cluster" "lke" {
  label       = "lke.tf"
  k8s_version = "1.21"
  region      = "us-central"
  tags        = ["lke", "terraform"]

  pool {
    type  = "g6-standard-2"
    count = 3
  }
}

resource "local_file" "lke_config" {
  content         = linode_lke_cluster.lke.kubeconfig
  filename        = "${path.module}/lke.config"
  file_permission = "0660"
}

provider "kubernetes" {
  config_paths = [local_file.lke_config.filename]
}


