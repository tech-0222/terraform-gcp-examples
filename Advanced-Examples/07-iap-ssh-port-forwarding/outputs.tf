output "project_id" {
  description = "Google Cloud Project ID."
  value       = var.project_id
}

output "instance_name" {
  description = "VM instance name."
  value       = google_compute_instance.vm.name
}

output "zone" {
  description = "VM zone."
  value       = google_compute_instance.vm.zone
}

output "internal_ip" {
  description = "VM internal IPv4 address."
  value       = google_compute_instance.vm.network_interface[0].network_ip
}

output "iap_ssh_command" {
  description = "Command to open an interactive SSH session through IAP."
  value       = "gcloud compute ssh ${google_compute_instance.vm.name} --zone=${google_compute_instance.vm.zone} --project=${var.project_id} --tunnel-through-iap"
}

output "http_tunnel_command" {
  description = "Command to forward local IPv4 port to nginx through IAP and SSH."
  value       = "gcloud compute ssh ${google_compute_instance.vm.name} --zone=${google_compute_instance.vm.zone} --project=${var.project_id} --tunnel-through-iap -- -N -L 127.0.0.1:${var.local_port}:127.0.0.1:80"
}

output "http_check_command" {
  description = "Command to verify the forwarded HTTP endpoint from another terminal."
  value       = "curl --fail --show-error http://127.0.0.1:${var.local_port}/"
}
