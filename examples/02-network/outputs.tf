output "network_name" {
  description = "VPC network name."
  value       = google_compute_network.vpc.name
}

output "network_id" {
  description = "VPC network ID."
  value       = google_compute_network.vpc.id
}

output "network_self_link" {
  description = "VPC network self link."
  value       = google_compute_network.vpc.self_link
}

output "subnet_name" {
  description = "Subnet name."
  value       = google_compute_subnetwork.primary.name
}

output "subnet_id" {
  description = "Subnet ID."
  value       = google_compute_subnetwork.primary.id
}

output "subnet_cidr" {
  description = "Subnet primary CIDR."
  value       = google_compute_subnetwork.primary.ip_cidr_range
}

output "firewall_names" {
  description = "Firewall rule names created by this sample."
  value = [
    google_compute_firewall.allow_internal.name,
    google_compute_firewall.allow_iap_ssh.name,
  ]
}
