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

output "default_compute_class_enabled_input" {
  description = "What Terraform was told to set. This is the input, not what GKE reports -- check the cluster itself with the command in show_cluster_autoscaling_example."
  value       = var.default_compute_class_enabled
}

output "show_cluster_autoscaling_example" {
  description = "Command that shows what GKE actually stored, including defaultComputeClassConfig."
  value       = "gcloud container clusters describe ${google_container_cluster.primary.name} --zone=${var.zone} --project=${var.project_id} --format='yaml(clusterAutoscaling)'"
}

output "bastion_name" {
  description = "Bastion VM name."
  value       = google_compute_instance.bastion.name
}

output "ssh_bastion_example" {
  description = "Example command to reach the bastion via IAP."
  value       = "gcloud compute ssh ${google_compute_instance.bastion.name} --zone=${var.zone} --tunnel-through-iap --project=${var.project_id}"
}

output "get_credentials_example" {
  description = "Example command, run from the bastion, to fetch kubeconfig for the private cluster."
  value       = "gcloud container clusters get-credentials ${google_container_cluster.primary.name} --zone=${var.zone} --project=${var.project_id}"
}
