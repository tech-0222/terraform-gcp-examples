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

output "zone" {
  description = "Zone used by the verification VMs."
  value       = var.zone
}

output "vm_in_zone_name" {
  description = "Name of the VM inside the VPC bound to the private zone."
  value       = google_compute_instance.vm_in_zone.name
}

output "vm_outside_zone_name" {
  description = "Name of the VM in the separate VPC, not bound to the private zone."
  value       = google_compute_instance.vm_outside_zone.name
}

output "ssh_in_zone_example" {
  description = "Example command to SSH into the VM inside the bound VPC."
  value       = "gcloud compute ssh ${google_compute_instance.vm_in_zone.name} --zone=${var.zone} --tunnel-through-iap --project=${var.project_id}"
}

output "ssh_outside_zone_example" {
  description = "Example command to SSH into the VM in the separate VPC."
  value       = "gcloud compute ssh ${google_compute_instance.vm_outside_zone.name} --zone=${var.zone} --tunnel-through-iap --project=${var.project_id}"
}
