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

output "workload_pool" {
  description = "Workload Identity pool. Used as PROJECT.svc.id.goog[NAMESPACE/KSA] when binding a KSA to a Google SA."
  value       = google_container_cluster.primary.workload_identity_config[0].workload_pool
}

output "bastion_name" {
  description = "Bastion VM name."
  value       = google_compute_instance.bastion.name
}

output "bastion_nat_egress_ip" {
  description = "Static Cloud NAT egress IP used by the bastion and GKE nodes for outbound traffic."
  value       = google_compute_address.nat_egress.address
}

output "secret_id" {
  description = "Secret Manager secret ID. Add a value with `gcloud secrets versions add` -- Terraform does not manage the value."
  value       = google_secret_manager_secret.demo.secret_id
}

output "secret_id_second" {
  description = "Second secret ID, used by the multi-secret example manifest."
  value       = google_secret_manager_secret.demo_second.secret_id
}

output "ksa_principal" {
  description = "IAM principal for the Kubernetes ServiceAccount. This is what holds secretAccessor -- no Google Service Account is involved."
  value       = local.ksa_principal
}

output "add_secret_version_example" {
  description = "Example command to put a value into the secret (run locally, outside Terraform)."
  value       = "printf '%s' 'your-secret-value' | gcloud secrets versions add ${google_secret_manager_secret.demo.secret_id} --data-file=- --project=${var.project_id}"
}

output "ssh_bastion_example" {
  description = "Example command to reach the bastion via IAP."
  value       = "gcloud compute ssh ${google_compute_instance.bastion.name} --zone=${var.zone} --tunnel-through-iap --project=${var.project_id}"
}

output "get_credentials_example" {
  description = "Example command, run from the bastion, to fetch kubeconfig for the private cluster."
  value       = "gcloud container clusters get-credentials ${google_container_cluster.primary.name} --zone=${var.zone} --project=${var.project_id}"
}
