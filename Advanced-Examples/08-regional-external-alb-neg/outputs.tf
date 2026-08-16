output "project_id" {
  description = "Google Cloud Project ID."
  value       = var.project_id
}

output "vip" {
  description = "Regional external Application Load Balancer VIP."
  value       = google_compute_address.vip.address
}

output "curl_port_81" {
  description = "Expect backend-a or backend-a2."
  value       = "curl -sS http://${google_compute_address.vip.address}:81/"
}

output "curl_port_82" {
  description = "Expect backend-b."
  value       = "curl -sS http://${google_compute_address.vip.address}:82/"
}
