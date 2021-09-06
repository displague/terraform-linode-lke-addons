provider "linode" {
  token = var.linode_token
}

module "lke" {
  source     = "./modules/kube"
  lke_config = "${path.module}/kube.config"
}

provider "kubernetes" {
  config_paths = [module.lke.lke_config]

  experiments {
    manifest_resource = true
  }
}

provider "kubectl" {
  config_path      = module.lke.lke_config
  load_config_file = true
}

provider "helm" {
  kubernetes {
    config_paths = [module.lke.lke_config]
  }
}

module "external_dns" {
  depends_on = [module.lke]
  source     = "./modules/external_dns"
}

module "cert_manager" {
  depends_on   = [module.lke]
  source       = "./modules/cert_manager"
  issuer_email = var.issuer_email
}

module "ingress_nginx" {
  depends_on = [module.lke, module.cert_manager]
  source     = "./modules/ingress_nginx"

  example_host = var.example_host
}

