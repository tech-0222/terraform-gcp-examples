output "project_id" {
  description = "Google Cloud Project ID."
  value       = var.project_id
}

output "region" {
  description = "Region used by this example."
  value       = var.region
}

output "zone" {
  description = "Zone of the bastion VM (the GKE cluster itself is regional; see gke_zones)."
  value       = var.zone
}

output "gke_zones" {
  description = "Zones the GKE node pool spans. GKE creates one standalone NEG per zone."
  value       = var.gke_zones
}

output "neg_name" {
  description = "Standalone NEG name, as declared in the Service's cloud.google.com/neg annotation."
  value       = var.neg_name
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

output "backend_service_name" {
  description = "Backend service that references the standalone NEGs. Inspect it with `gcloud compute backend-services describe/get-health` during the failure and recovery steps."
  value       = var.enable_lb ? one(google_compute_backend_service.lb[*].name) : null
}

output "lb_ip" {
  description = "External LB IP. Only set once enable_lb=true has been applied. curl it to see 200 (healthy) or 502 (no working backend)."
  value       = var.enable_lb ? one(google_compute_global_address.lb_vip[*].address) : null
}

output "ssh_bastion_example" {
  description = "Example command to reach the bastion via IAP."
  value       = "gcloud compute ssh ${google_compute_instance.bastion.name} --zone=${var.zone} --tunnel-through-iap --project=${var.project_id}"
}

output "get_credentials_example" {
  description = "Example command, run from the bastion, to fetch kubeconfig for the private cluster (regional cluster, so --region not --zone)."
  value       = "gcloud container clusters get-credentials ${google_container_cluster.primary.name} --region=${var.region} --project=${var.project_id}"
}
