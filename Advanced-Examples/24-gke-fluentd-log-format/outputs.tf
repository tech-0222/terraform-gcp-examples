output "project_id" {
  description = "Google Cloud Project ID."
  value       = var.project_id
}

output "zone" {
  description = "Zone of the cluster and the bastion VM."
  value       = var.zone
}

output "cluster_name" {
  description = "GKE cluster name."
  value       = google_container_cluster.primary.name
}

output "bastion_name" {
  description = "Bastion VM name."
  value       = google_compute_instance.bastion.name
}

output "logging_query_example" {
  description = "Command that shows what reached Cloud Logging from this cluster's workloads."
  value       = "gcloud logging read 'resource.type=\"k8s_container\" AND resource.labels.cluster_name=\"${google_container_cluster.primary.name}\" AND resource.labels.namespace_name=\"default\"' --limit=10 --format=json --project=${var.project_id}"
}

output "ssh_bastion_example" {
  description = "Example command to reach the bastion via IAP."
  value       = "gcloud compute ssh ${google_compute_instance.bastion.name} --zone=${var.zone} --tunnel-through-iap --project=${var.project_id}"
}

output "get_credentials_example" {
  description = "Example command, run from the bastion, to fetch kubeconfig for the private cluster."
  value       = "gcloud container clusters get-credentials ${google_container_cluster.primary.name} --zone=${var.zone} --project=${var.project_id}"
}
