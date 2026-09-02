# Project A: VPC, GKE/bastion subnets, Cloud NAT, IAP SSH firewalls.
resource "google_project_service" "a_required" {
  for_each = toset([
    "compute.googleapis.com",
    "container.googleapis.com",
  ])

  project = var.project_id
  service = each.value

  disable_on_destroy = false
}

resource "google_compute_network" "vpc_a" {
  name                    = var.network_a_name
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"

  depends_on = [google_project_service.a_required]
}

# GKE nodes live here. No secondary ranges -- this is a routes-based
# cluster, so pod_cidr/services_cidr are supplied directly to
# ip_allocation_policy and become VPC custom routes, not subnet ranges.
resource "google_compute_subnetwork" "gke" {
  name                     = "${var.network_a_name}-gke-subnet"
  ip_cidr_range            = var.gke_subnet_cidr
  region                   = var.region
  network                  = google_compute_network.vpc_a.id
  private_ip_google_access = true
}

resource "google_compute_subnetwork" "bastion" {
  name                     = "${var.network_a_name}-bastion-subnet"
  ip_cidr_range            = var.bastion_subnet_cidr
  region                   = var.region
  network                  = google_compute_network.vpc_a.id
  private_ip_google_access = true
}

resource "google_compute_address" "a_nat_egress" {
  name   = "${var.network_a_name}-nat-ip"
  region = var.region
}

resource "google_compute_router" "a_nat" {
  name    = "${var.network_a_name}-router"
  region  = var.region
  network = google_compute_network.vpc_a.id
}

resource "google_compute_router_nat" "a_nat" {
  name                               = "${var.network_a_name}-nat"
  router                             = google_compute_router.a_nat.name
  region                             = google_compute_router.a_nat.region
  nat_ip_allocate_option             = "MANUAL_ONLY"
  nat_ips                            = [google_compute_address.a_nat_egress.self_link]
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

resource "google_compute_firewall" "allow_iap_ssh_bastion" {
  name    = "${var.network_a_name}-allow-iap-ssh-bastion"
  network = google_compute_network.vpc_a.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["bastion"]
}

resource "google_compute_firewall" "allow_iap_ssh_gke_nodes" {
  name    = "${var.network_a_name}-allow-iap-ssh-gke-nodes"
  network = google_compute_network.vpc_a.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["gke-${var.cluster_name}"]
}

# Project B: VPC, target VM subnet, Cloud NAT, IAP SSH firewall.
resource "google_project_service" "b_required" {
  provider = google.b

  project = var.target_project_id
  service = "compute.googleapis.com"

  disable_on_destroy = false
}

resource "google_compute_network" "vpc_b" {
  provider = google.b

  name                    = var.network_b_name
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"

  depends_on = [google_project_service.b_required]
}

resource "google_compute_subnetwork" "target" {
  provider = google.b

  name                     = "${var.network_b_name}-subnet"
  ip_cidr_range            = var.target_subnet_cidr
  region                   = var.region
  network                  = google_compute_network.vpc_b.id
  private_ip_google_access = true
}

resource "google_compute_address" "b_nat_egress" {
  provider = google.b

  name   = "${var.network_b_name}-nat-ip"
  region = var.region
}

resource "google_compute_router" "b_nat" {
  provider = google.b

  name    = "${var.network_b_name}-router"
  region  = var.region
  network = google_compute_network.vpc_b.id
}

resource "google_compute_router_nat" "b_nat" {
  provider = google.b

  name                               = "${var.network_b_name}-nat"
  router                             = google_compute_router.b_nat.name
  region                             = google_compute_router.b_nat.region
  nat_ip_allocate_option             = "MANUAL_ONLY"
  nat_ips                            = [google_compute_address.b_nat_egress.self_link]
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = google_compute_subnetwork.target.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
}

resource "google_compute_firewall" "b_allow_iap_ssh" {
  provider = google.b

  name    = "${var.network_b_name}-allow-iap-ssh"
  network = google_compute_network.vpc_b.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["iap-ssh"]
}

# Only the GKE node subnet's range may reach the target VM's HTTP port.
# A Pod's own IP (pod_cidr) is deliberately NOT in this list -- that gap
# is what this example demonstrates and then works around.
resource "google_compute_firewall" "b_allow_http_from_a_nodes" {
  provider = google.b

  name    = "${var.network_b_name}-allow-http-from-a-nodes"
  network = google_compute_network.vpc_b.name

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = [var.gke_subnet_cidr]
  target_tags   = ["http"]
}

# --- VPC Peering (the mechanism under test) ---

resource "google_compute_network_peering" "a_to_b" {
  name         = "${var.network_a_name}-peer-to-b"
  network      = google_compute_network.vpc_a.self_link
  peer_network = google_compute_network.vpc_b.self_link

  export_custom_routes = var.peering_custom_routes
  import_custom_routes = var.peering_custom_routes
}

resource "google_compute_network_peering" "b_to_a" {
  provider = google.b

  # Creating both sides concurrently races against a GCP-side per-network
  # peering-operation lock ("There is a peering operation in progress on
  # the local or peer network"). Terraform can't infer this ordering on
  # its own since the two resources use different provider aliases /
  # projects, so it's explicit here.
  depends_on = [google_compute_network_peering.a_to_b]

  name         = "${var.network_b_name}-peer-to-a"
  network      = google_compute_network.vpc_b.self_link
  peer_network = google_compute_network.vpc_a.self_link

  export_custom_routes = var.peering_custom_routes
  import_custom_routes = var.peering_custom_routes
}
