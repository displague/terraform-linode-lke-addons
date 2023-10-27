provider "linode" {
  token = var.linode_token
}

module "lke" {
  source      = "./modules/kube"
  lke_config  = "${path.module}/kube.config"
  k8s_version = var.k8s_version
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

module "longhorn" {
  count      = var.longhorn_enabled ? 1 : 0
  depends_on = [module.lke]
  source     = "./modules/longhorn"
}

module "minecraft" {
  count      = (var.minecraft_ops != "" && var.minecraft_hostname != "") ? 1 : 0
  depends_on = [module.lke, module.longhorn]
  source     = "./modules/minecraft"
  ops        = var.minecraft_ops
  hostname   = var.minecraft_hostname
  motd       = var.minecraft_motd
}

module "triage" {
  count       = (var.gh_token != "" && var.triage_host != "") ? 1 : 0
  depends_on  = [module.lke]
  source      = "./modules/triage"
  gh_token    = var.gh_token
  triage_host = var.triage_host
}

module "jhub" {
  count          = (var.jhub_hostname != "" && var.jhub_client_id != "" && var.jhub_client_secret != "") ? 1 : 0
  depends_on     = [module.lke]
  source         = "./modules/jhub"
  hostname       = var.jhub_hostname
  client_id      = var.jhub_client_id
  client_secret  = var.jhub_client_secret
  gh_admin_users = var.gh_admin_users
}
