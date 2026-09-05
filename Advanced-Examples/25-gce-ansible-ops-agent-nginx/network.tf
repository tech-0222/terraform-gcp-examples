# VPC, subnet, Cloud NAT and the two firewall rules this example needs.
#
# The VM has no external IP. Cloud NAT gives it outbound access (apt, the Ops
# Agent installer), and IAP TCP forwarding gives us inbound access -- both for
# SSH and, on port 80, for curling nginx from outside the VPC without ever
# exposing it to the internet.
resource "google_project_service" "required" {
  for_each = toset([
    "compute.googleapis.com",
    "iap.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
  ])

  project = var.project_id
  service = each.value

  disable_on_destroy = false
}

resource "google_compute_network" "vpc" {
  name                    = var.network_name
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"

  depends_on = [google_project_service.required]
}

resource "google_compute_subnetwork" "main" {
  name                     = var.subnet_name
  ip_cidr_range            = var.subnet_cidr
  region                   = var.region
  network                  = google_compute_network.vpc.id
  private_ip_google_access = true
}

resource "google_compute_address" "nat_egress" {
  name   = "${var.network_name}-nat-ip"
  region = var.region
}

resource "google_compute_router" "nat" {
  name    = "${var.network_name}-router"
  region  = var.region
  network = google_compute_network.vpc.id
}

resource "google_compute_router_nat" "nat" {
  name                               = "${var.network_name}-nat"
  router                             = google_compute_router.nat.name
  region                             = google_compute_router.nat.region
  nat_ip_allocate_option             = "MANUAL_ONLY"
  nat_ips                            = [google_compute_address.nat_egress.self_link]
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

# SSH via IAP.
resource "google_compute_firewall" "allow_iap_ssh" {
  name    = "${var.network_name}-allow-iap-ssh"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["web"]
}

# HTTP via IAP. This is what lets `gcloud compute start-iap-tunnel` reach
# nginx on port 80, so the service can be curled from outside the VPC without
# giving the VM an external IP.
# Ref: https://cloud.google.com/iap/docs/using-tcp-forwarding
resource "google_compute_firewall" "allow_iap_http" {
  name    = "${var.network_name}-allow-iap-http"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["web"]
}
