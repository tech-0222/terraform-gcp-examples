# Network prerequisites: VPC, GKE/bastion subnets, Cloud NAT, IAP SSH firewalls.
# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_project_service
resource "google_project_service" "required" {
  for_each = toset([
    "compute.googleapis.com",
    "container.googleapis.com",
    "artifactregistry.googleapis.com",
  ])

  project = var.project_id
  service = each.value

  disable_on_destroy = false
}

# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network
resource "google_compute_network" "vpc" {
  name                    = var.network_name
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"

  depends_on = [google_project_service.required]
}

# GKE nodes live here. Secondary ranges are required for a VPC-native cluster.
# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork
resource "google_compute_subnetwork" "gke" {
  name                     = var.gke_subnet_name
  ip_cidr_range            = var.gke_subnet_cidr
  region                   = var.region
  network                  = google_compute_network.vpc.id
  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = var.pods_cidr
  }
  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = var.services_cidr
  }
}

# Bastion lives in a separate subnet so master_authorized_networks can allow
# only this CIDR, not the whole GKE subnet.
resource "google_compute_subnetwork" "bastion" {
  name                     = var.bastion_subnet_name
  ip_cidr_range            = var.bastion_subnet_cidr
  region                   = var.region
  network                  = google_compute_network.vpc.id
  private_ip_google_access = true
}

# Static egress IP so the NAT address is stable and visible in outputs.
# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_address
resource "google_compute_address" "nat_egress" {
  name   = "${var.network_name}-nat-ip"
  region = var.region
}

# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router
resource "google_compute_router" "nat" {
  name    = "${var.network_name}-router"
  region  = var.region
  network = google_compute_network.vpc.id
}

# Both subnets have no external IPs, so Cloud NAT is required for outbound
# access (apt/dnf on the bastion, image pulls on the nodes). The private
# GKE control plane itself does not use NAT.
# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router_nat
resource "google_compute_router_nat" "nat" {
  name                               = "${var.network_name}-nat"
  router                             = google_compute_router.nat.name
  region                             = google_compute_router.nat.region
  nat_ip_allocate_option             = "MANUAL_ONLY"
  nat_ips                            = [google_compute_address.nat_egress.self_link]
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = google_compute_subnetwork.bastion.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
  subnetwork {
    name                    = google_compute_subnetwork.gke.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
}

# Allow SSH via IAP only, to the bastion.
# Ref: https://cloud.google.com/iap/docs/using-tcp-forwarding
resource "google_compute_firewall" "allow_iap_ssh_bastion" {
  name    = "${var.network_name}-allow-iap-ssh-bastion"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["bastion"]
}

# Allow SSH via IAP directly to GKE nodes too (Standard nodes are regular
# Compute Engine instances, so the same IAP pattern applies).
resource "google_compute_firewall" "allow_iap_ssh_gke_nodes" {
  name    = "${var.network_name}-allow-iap-ssh-gke-nodes"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["gke-${var.cluster_name}"]
}
