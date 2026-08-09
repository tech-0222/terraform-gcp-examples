output "cluster_name" {
  description = "GKE cluster name."
  value       = google_container_cluster.primary.name
}

output "cluster_location" {
  description = "GKE cluster location (zone)."
  value       = google_container_cluster.primary.location
}

output "cluster_endpoint" {
  description = "GKE API endpoint."
  value       = google_container_cluster.primary.endpoint
  sensitive   = true
}

output "network_name" {
  description = "VPC network name."
  value       = google_compute_network.vpc.name
}

output "get_credentials_example" {
  description = "Example command to fetch kubeconfig."
  value       = "gcloud container clusters get-credentials ${google_container_cluster.primary.name} --zone=${google_container_cluster.primary.location} --project=${var.project_id}"
}
