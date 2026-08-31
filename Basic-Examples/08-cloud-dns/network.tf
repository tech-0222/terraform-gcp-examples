# Network prerequisites for the private Cloud DNS sample.
# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_project_service
resource "google_project_service" "compute" {
  project = var.project_id
  service = "compute.googleapis.com"

  disable_on_destroy = false
}

# VPC bound to the private zone (private_visibility_config in main.tf).
# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network
resource "google_compute_network" "dns" {
  name                    = var.network_name
  auto_create_subnetworks = false

  depends_on = [google_project_service.compute]
}

# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork
resource "google_compute_subnetwork" "dns" {
  name          = var.subnet_name
  ip_cidr_range = var.subnet_cidr
  region        = var.region
  network       = google_compute_network.dns.id
}

# Allow SSH via IAP only.
# Ref: https://cloud.google.com/iap/docs/using-tcp-forwarding
resource "google_compute_firewall" "allow_iap_ssh_dns" {
  name    = "${var.network_name}-allow-iap-ssh"
  network = google_compute_network.dns.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["iap-ssh"]
}

# Separate VPC, deliberately NOT bound to the private zone. Used to verify
# that resolution fails from a network the zone is not authorized for.
# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network
resource "google_compute_network" "external" {
  name                    = var.external_network_name
  auto_create_subnetworks = false

  depends_on = [google_project_service.compute]
}

# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork
resource "google_compute_subnetwork" "external" {
  name          = var.external_subnet_name
  ip_cidr_range = var.external_subnet_cidr
  region        = var.region
  network       = google_compute_network.external.id
}

# Ref: https://cloud.google.com/iap/docs/using-tcp-forwarding
resource "google_compute_firewall" "allow_iap_ssh_external" {
  name    = "${var.external_network_name}-allow-iap-ssh"
  network = google_compute_network.external.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["iap-ssh"]
}
