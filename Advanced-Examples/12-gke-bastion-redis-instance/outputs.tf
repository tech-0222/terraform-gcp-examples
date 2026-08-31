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

output "artifact_registry_repository_url" {
  description = "Artifact Registry Docker repository URL (docker push/pull base)."
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${var.artifact_registry_repository_id}"
}

output "artifact_registry_nginx_image" {
  description = "Full URL for the nginx image used in the verification step."
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${var.artifact_registry_repository_id}/nginx:latest"
}

output "ssh_bastion_example" {
  description = "Example command to reach the bastion via IAP."
  value       = "gcloud compute ssh ${google_compute_instance.bastion.name} --zone=${var.zone} --tunnel-through-iap --project=${var.project_id}"
}

output "get_credentials_example" {
  description = "Example command, run from the bastion, to fetch kubeconfig for the private cluster."
  value       = "gcloud container clusters get-credentials ${google_container_cluster.primary.name} --zone=${var.zone} --project=${var.project_id}"
}

output "redis_host" {
  description = "Redis private IP, reachable from Pods over the GKE VPC."
  value       = google_redis_instance.cache.host
}

output "redis_port" {
  description = "Redis port (6379)."
  value       = google_redis_instance.cache.port
}
