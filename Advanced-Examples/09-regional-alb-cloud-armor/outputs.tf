output "vip" {
  description = "Regional external Application Load Balancer VIP (port 80)."
  value       = google_compute_address.vip.address
}

output "curl_allowlisted" {
  description = "From an allowlisted public IP, expect HTTP 200 and backend-a."
  value       = "curl -si http://${google_compute_address.vip.address}/"
}

output "deny_client_ssh" {
  description = "IAP SSH to the optional deny-client VM (expect 403 when curling the VIP from that VM)."
  value       = var.create_deny_client ? "gcloud compute ssh ${google_compute_instance.deny_client[0].name} --zone=${var.zone} --tunnel-through-iap" : "create_deny_client is false"
}
