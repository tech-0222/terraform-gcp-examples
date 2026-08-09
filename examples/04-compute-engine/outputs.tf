output "instance_name" {
  description = "VM instance name."
  value       = google_compute_instance.vm.name
}

output "instance_id" {
  description = "VM instance ID."
  value       = google_compute_instance.vm.instance_id
}

output "zone" {
  description = "VM zone."
  value       = google_compute_instance.vm.zone
}

output "internal_ip" {
  description = "VM internal IP address."
  value       = google_compute_instance.vm.network_interface[0].network_ip
}

output "network_name" {
  description = "VPC network name."
  value       = google_compute_network.vpc.name
}

output "ssh_via_iap_example" {
  description = "Example command to SSH via IAP."
  value       = "gcloud compute ssh ${google_compute_instance.vm.name} --zone=${google_compute_instance.vm.zone} --tunnel-through-iap --project=${var.project_id}"
}
