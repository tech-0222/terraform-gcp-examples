output "network_name" {
  description = "VPC network name associated with the private DNS zone."
  value       = google_compute_network.dns.name
}

output "managed_zone_name" {
  description = "Cloud DNS managed zone name."
  value       = google_dns_managed_zone.private.name
}

output "dns_name" {
  description = "Private DNS suffix."
  value       = google_dns_managed_zone.private.dns_name
}

output "record_fqdn" {
  description = "FQDN of the sample A record."
  value       = google_dns_record_set.example.name
}

output "record_ip" {
  description = "IPv4 address configured in the sample A record."
  value       = var.record_ip
}
