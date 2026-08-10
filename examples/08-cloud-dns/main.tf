locals {
  record_fqdn = "${var.record_name}.${var.dns_name}"
}

# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_project_service
resource "google_project_service" "dns" {
  project = var.project_id
  service = "dns.googleapis.com"

  disable_on_destroy = false
}

# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dns_managed_zone
resource "google_dns_managed_zone" "private" {
  name        = var.managed_zone_name
  dns_name    = var.dns_name
  description = "Private DNS zone for terraform-gcp-examples"
  visibility  = "private"

  private_visibility_config {
    networks {
      network_url = google_compute_network.dns.id
    }
  }

  depends_on = [google_project_service.dns]
}

# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dns_record_set
resource "google_dns_record_set" "example" {
  name         = local.record_fqdn
  managed_zone = google_dns_managed_zone.private.name
  type         = "A"
  ttl          = var.record_ttl
  rrdatas      = [var.record_ip]
}
