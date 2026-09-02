output "project_id" {
  description = "Project A: Google Cloud Project ID (GKE + bastion)."
  value       = var.project_id
}

output "target_project_id" {
  description = "Project B: Google Cloud Project ID (destination VM)."
  value       = var.target_project_id
}

output "region" {
  description = "Region used by this example."
  value       = var.region
}

output "zone" {
  description = "Zone of the cluster, the bastion VM, and the target VM."
  value       = var.zone
}

output "cluster_name" {
  description = "GKE cluster name."
  value       = google_container_cluster.primary.name
}

output "pod_cidr" {
  description = "Pod CIDR. On this routes-based cluster it is a VPC custom route, not a subnet secondary range."
  value       = var.pod_cidr
}

output "peering_custom_routes" {
  description = "Whether the VPC Peering exports/imports custom routes (false = Project B never learns a route to pod_cidr)."
  value       = var.peering_custom_routes
}

output "bastion_name" {
  description = "Bastion VM name (Project A)."
  value       = google_compute_instance.bastion.name
}

output "target_vm_name" {
  description = "Destination VM name (Project B)."
  value       = google_compute_instance.target_vm.name
}

output "target_vm_ip" {
  description = "Destination VM's internal IP -- the curl target from inside the cluster."
  value       = google_compute_instance.target_vm.network_interface[0].network_ip
}

output "ssh_bastion_example" {
  description = "Example command to reach the bastion via IAP."
  value       = "gcloud compute ssh ${google_compute_instance.bastion.name} --zone=${var.zone} --tunnel-through-iap --project=${var.project_id}"
}

output "ssh_target_vm_example" {
  description = "Example command to reach the target VM via IAP (for tcpdump during verification)."
  value       = "gcloud compute ssh ${google_compute_instance.target_vm.name} --zone=${var.zone} --tunnel-through-iap --project=${var.target_project_id}"
}

output "get_credentials_example" {
  description = "Example command, run from the bastion, to fetch kubeconfig for the private cluster."
  value       = "gcloud container clusters get-credentials ${google_container_cluster.primary.name} --zone=${var.zone} --project=${var.project_id}"
}
