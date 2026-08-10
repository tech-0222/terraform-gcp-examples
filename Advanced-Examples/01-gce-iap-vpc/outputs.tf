output "instance_name" {
  description = "VM instance name."
  value       = google_compute_instance.vm.name
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

output "vm_service_account_email" {
  description = "Runtime service account email attached to the VM."
  value       = google_service_account.vm.email
}

output "iap_member" {
  description = "Principal granted IAP tunnel + OS Login."
  value       = var.iap_member
}

output "ssh_via_iap_example" {
  description = "Example command to SSH via IAP."
  value       = "gcloud compute ssh ${google_compute_instance.vm.name} --zone=${google_compute_instance.vm.zone} --tunnel-through-iap --project=${var.project_id}"
}
