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

output "private_endpoint" {
  description = "GKE control plane private endpoint (reachable only from the bastion subnet)."
  value       = google_container_cluster.primary.private_cluster_config[0].private_endpoint
}

output "kms_key_id" {
  description = "Crypto key used for the node boot disks. Both node pools reference this same key."
  value       = google_kms_crypto_key.boot_disk.id
}

output "kms_key_ring_name" {
  description = "Key ring name. Cannot be deleted -- reuse or rename it when re-running this example."
  value       = google_kms_key_ring.boot_disk.name
}

output "node_pool_names" {
  description = "Node pools that currently exist, driven by keep_v1_node_pool / create_v2_node_pool."
  value = concat(
    [for p in google_container_node_pool.v1 : p.name],
    [for p in google_container_node_pool.v2 : p.name],
  )
}

output "bastion_name" {
  description = "Bastion VM name."
  value       = google_compute_instance.bastion.name
}

output "bastion_nat_egress_ip" {
  description = "Static Cloud NAT egress IP used by the bastion and GKE nodes for outbound traffic."
  value       = google_compute_address.nat_egress.address
}

output "rotate_key_example" {
  description = "Command that creates a new key version and makes it primary. Run it before setting create_v2_node_pool = true."
  value       = "gcloud kms keys versions create --key=${google_kms_crypto_key.boot_disk.name} --keyring=${google_kms_key_ring.boot_disk.name} --location=${var.region} --primary --project=${var.project_id}"
}

output "list_key_versions_example" {
  description = "Command to list key versions and see which one is primary."
  value       = "gcloud kms keys versions list --key=${google_kms_crypto_key.boot_disk.name} --keyring=${google_kms_key_ring.boot_disk.name} --location=${var.region} --project=${var.project_id}"
}

output "ssh_bastion_example" {
  description = "Example command to reach the bastion via IAP."
  value       = "gcloud compute ssh ${google_compute_instance.bastion.name} --zone=${var.zone} --tunnel-through-iap --project=${var.project_id}"
}

output "get_credentials_example" {
  description = "Example command, run from the bastion, to fetch kubeconfig for the private cluster."
  value       = "gcloud container clusters get-credentials ${google_container_cluster.primary.name} --zone=${var.zone} --project=${var.project_id}"
}
