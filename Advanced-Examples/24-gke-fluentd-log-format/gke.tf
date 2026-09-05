# GKE Standard: private endpoint + private nodes.
#
# The subject here is not the cluster, it is what reaches Cloud Logging. GKE's
# logging agent picks up every container's stdout on its own; a Fluentd sidecar
# adds a second path. This example runs both so the two can be compared in the
# same query.

resource "google_service_account" "gke_node" {
  account_id   = "${var.cluster_name}-node"
  display_name = "GKE node pool (${var.cluster_name})"
}

resource "google_project_iam_member" "gke_node" {
  for_each = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
  ])

  project = var.project_id
  role    = each.value
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

  # SYSTEM_COMPONENTS,WORKLOADS is the default. Stated explicitly because it
  # is the reason container stdout reaches Cloud Logging without any sidecar --
  # which is what the sidecar has to be compared against.
  # Ref: https://cloud.google.com/kubernetes-engine/docs/how-to/configure-logging
  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }

  resource_labels = {
    env        = "test"
    system     = "tf-examples"
    component  = "gke"
    managed_by = "terraform"
    example    = "24-gke-fluentd-log-format"
  }

  depends_on = [google_compute_subnetwork.gke]
}

# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_node_pool
resource "google_container_node_pool" "primary" {
  name     = "${var.cluster_name}-np"
  location = var.zone
  cluster  = google_container_cluster.primary.name

  node_count = var.node_count

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type    = var.node_machine_type
    disk_size_gb    = 30
    disk_type       = "pd-balanced"
    service_account = google_service_account.gke_node.email
    spot            = var.use_spot

    oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]

    labels = {
      component  = "gke"
      managed_by = "terraform"
      example    = "24-gke-fluentd-log-format"
    }

    tags = ["gke-${var.cluster_name}"]
  }

  depends_on = [google_project_iam_member.gke_node]
}
