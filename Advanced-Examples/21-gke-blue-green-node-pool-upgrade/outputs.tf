output "project_id" {
  description = "Google Cloud Project ID."
  value       = var.project_id
}

output "region" {
  description = "Region used by this example."
  value       = var.region
}

output "zone" {
  description = "Zone of the cluster and the bastion VM."
  value       = var.zone
}

output "cluster_name" {
  description = "GKE cluster name."
  value       = google_container_cluster.primary.name
}

output "node_pool_name" {
  description = "Node pool that carries the BLUE_GREEN upgrade settings."
  value       = google_container_node_pool.primary.name
}

output "master_version" {
  description = "Control plane version. The node pool upgrades to this."
  value       = google_container_cluster.primary.master_version
}

output "kms_key_id" {
  description = "Crypto key used for the node boot disks."
  value       = google_kms_crypto_key.boot_disk.id
}

output "bastion_name" {
  description = "Bastion VM name."
  value       = google_compute_instance.bastion.name
}

output "upgrade_node_pool_example" {
  description = "Command that starts the BLUE_GREEN upgrade. Run it after the initial apply."
  value       = "gcloud container clusters upgrade ${google_container_cluster.primary.name} --node-pool=${google_container_node_pool.primary.name} --cluster-version=${var.master_version} --zone=${var.zone} --project=${var.project_id} --async"
}

output "rollback_node_pool_example" {
  description = "Command that rolls the upgrade back. Only works while blue still exists, i.e. before node_pool_soak_duration expires."
  value       = "gcloud container node-pools rollback ${google_container_node_pool.primary.name} --cluster=${google_container_cluster.primary.name} --zone=${var.zone} --project=${var.project_id}"
}

output "show_upgrade_settings_example" {
  description = "Command to confirm the BLUE_GREEN settings landed in GKE."
  value       = "gcloud container node-pools describe ${google_container_node_pool.primary.name} --cluster=${google_container_cluster.primary.name} --zone=${var.zone} --project=${var.project_id} --format='yaml(upgradeSettings)'"
}

output "ssh_bastion_example" {
  description = "Example command to reach the bastion via IAP."
  value       = "gcloud compute ssh ${google_compute_instance.bastion.name} --zone=${var.zone} --tunnel-through-iap --project=${var.project_id}"
}

output "get_credentials_example" {
  description = "Example command, run from the bastion, to fetch kubeconfig for the private cluster."
  value       = "gcloud container clusters get-credentials ${google_container_cluster.primary.name} --zone=${var.zone} --project=${var.project_id}"
}
