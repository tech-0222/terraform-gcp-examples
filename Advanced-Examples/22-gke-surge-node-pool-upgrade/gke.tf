# GKE Standard: private endpoint + private nodes, one node pool that upgrades
# with the SURGE strategy (GKE's default).
#
# SURGE replaces nodes in place, a few at a time: it adds up to max_surge extra
# nodes, drains an equal number of old ones, and repeats. There is no second
# pool and no soak period -- which also means there is nothing to roll back to
# once a node has been replaced.
#
# This example is deliberately identical to 21-gke-blue-green-node-pool-upgrade
# except for upgrade_settings, so the two strategies can be measured with the
# same yardstick.

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

  # The control plane is created at this version so the node pool has
  # somewhere to upgrade to. A node pool can never run ahead of the control
  # plane, so pinning only the node pool would leave nothing to test.
  # Ref: https://cloud.google.com/kubernetes-engine/docs/concepts/cluster-upgrades
  min_master_version = var.master_version

  release_channel {
    channel = var.release_channel
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

  resource_labels = {
    env        = "test"
    system     = "tf-examples"
    component  = "gke"
    managed_by = "terraform"
    example    = "22-gke-surge-node-pool-upgrade"
  }

  depends_on = [google_compute_subnetwork.gke]
}

# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_node_pool
resource "google_container_node_pool" "primary" {
  name     = "${var.cluster_name}-np"
  location = var.zone
  cluster  = google_container_cluster.primary.name

  node_count = var.node_count

  # Deliberately behind the control plane, which is what gives the upgrade
  # something to do. lifecycle.ignore_changes below keeps Terraform from
  # dragging it back down after gcloud upgrades it.
  version = var.node_pool_version

  management {
    # Left off so the upgrade happens when this example triggers it, not
    # whenever GKE decides to.
    auto_repair  = true
    auto_upgrade = false
  }

  # max_surge and max_unavailable belong to SURGE; blue_green_settings belongs
  # to BLUE_GREEN. The API rejects the wrong pairing.
  #
  # The two together decide how many nodes are worked on at once:
  #   max_surge = 1, max_unavailable = 0  extra node first, then drain (default)
  #   max_surge = 0, max_unavailable = 1  drain first, no extra node
  # The first costs an extra node but keeps capacity; the second is free but
  # runs the pool short while a node is being replaced.
  # Ref: https://cloud.google.com/kubernetes-engine/docs/concepts/node-pool-upgrade-strategies
  upgrade_settings {
    strategy        = "SURGE"
    max_surge       = var.max_surge
    max_unavailable = var.max_unavailable
  }

  node_config {
    machine_type    = var.node_machine_type
    disk_size_gb    = 30
    disk_type       = "pd-balanced"
    service_account = google_service_account.gke_node.email
    spot            = var.use_spot

    boot_disk_kms_key = google_kms_crypto_key.boot_disk.id

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]

    labels = {
      component  = "gke"
      managed_by = "terraform"
      example    = "22-gke-surge-node-pool-upgrade"
    }

    tags = ["gke-${var.cluster_name}"]
  }

  lifecycle {
    # The upgrade is driven by `gcloud container clusters upgrade`, so after
    # it runs the live version no longer matches var.node_pool_version.
    # Without this, the next apply would try to downgrade the pool.
    ignore_changes = [version]
  }

  depends_on = [
    google_kms_crypto_key_iam_member.compute_agent,
    google_kms_crypto_key_iam_member.container_agent,
    google_project_iam_member.gke_node_logging,
    google_project_iam_member.gke_node_monitoring_metric,
    google_project_iam_member.gke_node_monitoring_viewer,
  ]
}
