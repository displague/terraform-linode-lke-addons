output "lke_config" {
  value = local_file.lke_config.filename
}

output "lke_id" {
  description = "ID of the Linode LKE Cluster created"
  value = linode_lke_cluster.lke.id
}
