# GKE Standard: private nodes, with BOTH the private and public control
# plane endpoint enabled (unlike 11/12/13/14, which set
# enable_private_endpoint=true and so disable the public endpoint
# entirely -- see private_cluster_config below for why that flag can't be
# true here). Access to both endpoints is restricted by
# master_authorized_networks.

# Dedicated node Service Account instead of the Compute Engine default SA.
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

  network    = google_compute_network.vpc.name
  subnetwork = google_compute_subnetwork.gke.name

  remove_default_node_pool = true
  initial_node_count       = 1

  deletion_protection = false

  release_channel {
    channel = "REGULAR"
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  # enable_private_endpoint MUST be false here. Per the provider schema:
  # "When true, the cluster's private endpoint is used as the cluster
  # endpoint and access through the public endpoint is disabled. When
  # false, either endpoint can be used." Setting it true (as 11/12/13/14
  # do for a fully private cluster) would silently disable the public
  # endpoint regardless of master_authorized_networks -- there would be
  # no dual-endpoint behavior to demonstrate.
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = var.master_ipv4_cidr_block
  }

  # Both the bastion subnet (private endpoint, from inside the VPC) and
  # admin_public_cidr (public endpoint, from outside) must be listed here.
  # Without this block at all, the public endpoint would be reachable from
  # any IP -- authorized networks is what makes it "restricted public",
  # not "open public".
  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = var.bastion_subnet_cidr
      display_name = "bastion-subnet"
    }
    cidr_blocks {
      cidr_block   = var.admin_public_cidr
      display_name = "admin-public"
    }
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  resource_labels = {
    env        = "test"
    system     = "tf-examples"
    component  = "gke"
    managed_by = "terraform"
    example    = "15-gke-dual-endpoint"
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

    # Required for Workload Identity: lets Pods fetch tokens through the
    # GKE metadata server instead of the node's own credentials.
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    labels = {
      component  = "gke"
      managed_by = "terraform"
      example    = "15-gke-dual-endpoint"
    }

    tags = ["gke-${var.cluster_name}"]
  }

  depends_on = [
    google_project_iam_member.gke_node_logging,
    google_project_iam_member.gke_node_monitoring_metric,
    google_project_iam_member.gke_node_monitoring_viewer,
  ]
}
