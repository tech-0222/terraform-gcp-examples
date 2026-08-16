# Workload VPC plus the proxy-only subnet required by regional Envoy ALB.
# Ref: https://cloud.google.com/load-balancing/docs/proxy-only-subnets
resource "google_project_service" "required" {
  for_each = toset([
    "compute.googleapis.com",
  ])

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_compute_network" "vpc" {
  name                    = var.network_name
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"

  depends_on = [google_project_service.required]
}

resource "google_compute_subnetwork" "workload" {
  name                     = var.subnet_name
  region                   = var.region
  network                  = google_compute_network.vpc.id
  ip_cidr_range            = var.subnet_cidr
  private_ip_google_access = true
}

# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork
resource "google_compute_subnetwork" "proxy_only" {
  name          = var.proxy_subnet_name
  region        = var.region
  network       = google_compute_network.vpc.id
  ip_cidr_range = var.proxy_subnet_cidr
  purpose       = "REGIONAL_MANAGED_PROXY"
  role          = "ACTIVE"
}

resource "google_compute_router" "router" {
  name    = "${var.network_name}-router"
  region  = var.region
  network = google_compute_network.vpc.id
}

# NAT is outbound-only (apt / python packages). It is not the inbound ALB path.
resource "google_compute_router_nat" "nat" {
  name                               = "${var.network_name}-nat"
  router                             = google_compute_router.router.name
  region                             = google_compute_router.router.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = google_compute_subnetwork.workload.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
}

# Google health checkers -> backend :8080
# Ref: https://cloud.google.com/load-balancing/docs/health-check-concepts#ip-ranges
resource "google_compute_firewall" "allow_health_check" {
  name    = "${var.network_name}-allow-hc"
  network = google_compute_network.vpc.name

  direction     = "INGRESS"
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
  target_tags   = ["lb-backend"]

  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }
}

# Envoy in the proxy-only subnet -> backend :8080
resource "google_compute_firewall" "allow_proxies" {
  name    = "${var.network_name}-allow-proxies"
  network = google_compute_network.vpc.name

  direction     = "INGRESS"
  source_ranges = [var.proxy_subnet_cidr]
  target_tags   = ["lb-backend"]

  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }
}

resource "google_compute_firewall" "allow_iap_ssh" {
  name    = "${var.network_name}-allow-iap-ssh"
  network = google_compute_network.vpc.name

  direction     = "INGRESS"
  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["iap-ssh"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}
