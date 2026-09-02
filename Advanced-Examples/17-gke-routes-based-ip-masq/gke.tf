# GKE Standard, routes-based (networking_mode = "ROUTES", the implicit
# default when ip_allocation_policy carries plain CIDR blocks instead of
# secondary range names). Kept deliberately minimal -- Dataplane V2 and
# other hardening flags are out of scope here; see
# 16-gke-dataplane-v2-networkpolicy for those. The only thing this
# example needs is routes-based Pod IP allocation.

resource "google_service_account" "gke_node" {
  account_id   = "${var.cluster_name}-node"
  display_name = "GKE node pool (${var.cluster_name})"
}

resource "google_project_iam_member" "gke_node_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.gke_node.email}"
}

resource "google_project_iam_member" "gke_node_monitoring_metric" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.gke_node.email}"
}

resource "google_project_iam_member" "gke_node_monitoring_viewer" {
  project = var.project_id
  role    = "roles/monitoring.viewer"
  member  = "serviceAccount:${google_service_account.gke_node.email}"
}

# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_cluster
resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.zone

  network    = google_compute_network.vpc_a.name
  subnetwork = google_compute_subnetwork.gke.name

  remove_default_node_pool = true
  initial_node_count       = 1

  deletion_protection = false

  # Supplying plain CIDR blocks here (instead of
  # cluster/services_secondary_range_name) makes this a routes-based
  # cluster: Pod IP reachability becomes a VPC custom route, not a subnet
  # secondary range. Ref:
  # https://cloud.google.com/kubernetes-engine/docs/how-to/routes-based-cluster
  ip_allocation_policy {
    cluster_ipv4_cidr_block  = var.pod_cidr
    services_ipv4_cidr_block = var.services_cidr
  }

  release_channel {
    channel = "REGULAR"
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = true
    master_ipv4_cidr_block  = var.master_ipv4_cidr_block
  }

  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = var.bastion_subnet_cidr
      display_name = "bastion-subnet"
    }
  }

  resource_labels = {
    env        = "test"
    system     = "tf-examples"
    component  = "gke"
    managed_by = "terraform"
    example    = "17-gke-routes-based-ip-masq"
  }

  depends_on = [google_compute_subnetwork.gke]
}

# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_node_pool
resource "google_container_node_pool" "primary" {
  name     = "${var.cluster_name}-np"
  location = var.zone
  cluster  = google_container_cluster.primary.name

  node_count = 1

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type    = var.node_machine_type
    disk_size_gb    = 30
    disk_type       = "pd-standard"
    service_account = google_service_account.gke_node.email
    spot            = var.use_spot

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]

    labels = {
      component  = "gke"
      managed_by = "terraform"
      example    = "17-gke-routes-based-ip-masq"
    }

    tags = ["gke-${var.cluster_name}"]
  }

  depends_on = [
    google_project_iam_member.gke_node_logging,
    google_project_iam_member.gke_node_monitoring_metric,
    google_project_iam_member.gke_node_monitoring_viewer,
  ]
}
