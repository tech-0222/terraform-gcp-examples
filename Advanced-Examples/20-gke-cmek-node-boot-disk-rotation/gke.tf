# GKE Standard: private endpoint + private nodes, with CMEK-encrypted node
# boot disks. Two node pools are defined and gated by variables so the
# migration can be driven entirely through `terraform apply`:
#
#   phase 1 (initial)  keep_v1_node_pool = true,  create_v2_node_pool = false
#   phase 2 (rotated)  keep_v1_node_pool = true,  create_v2_node_pool = true
#   phase 3 (migrated) keep_v1_node_pool = false, create_v2_node_pool = true
#
# Both pools point at the SAME crypto key. What differs is *when* the pool is
# created: a disk is encrypted with whichever key version is primary at that
# moment, and it is never re-encrypted afterwards.

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
    example    = "20-gke-cmek-node-boot-disk-rotation"
  }

  depends_on = [google_compute_subnetwork.gke]
}

# v1 pool: created before the key is rotated, so its disks carry the key
# version that was primary at creation time.
# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_node_pool
resource "google_container_node_pool" "v1" {
  count = var.keep_v1_node_pool ? 1 : 0

  name     = "${var.cluster_name}-np-v1"
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

    # This is the CMEK setting. It is immutable: an existing node pool
    # cannot be switched to another key, which is why migrating means
    # creating a new pool rather than editing this one.
    boot_disk_kms_key = google_kms_crypto_key.boot_disk.id

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]

    labels = {
      component  = "gke"
      managed_by = "terraform"
      example    = "20-gke-cmek-node-boot-disk-rotation"
      pool       = "v1"
    }

    tags = ["gke-${var.cluster_name}"]
  }

  depends_on = [
    google_kms_crypto_key_iam_member.compute_agent,
    google_kms_crypto_key_iam_member.container_agent,
    google_project_iam_member.gke_node_logging,
    google_project_iam_member.gke_node_monitoring_metric,
    google_project_iam_member.gke_node_monitoring_viewer,
  ]
}

# v2 pool: identical except for the name. Applied after the key rotation so
# its disks pick up the new primary key version.
resource "google_container_node_pool" "v2" {
  count = var.create_v2_node_pool ? 1 : 0

  name     = "${var.cluster_name}-np-v2"
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

    boot_disk_kms_key = google_kms_crypto_key.boot_disk.id

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]

    labels = {
      component  = "gke"
      managed_by = "terraform"
      example    = "20-gke-cmek-node-boot-disk-rotation"
      pool       = "v2"
    }

    tags = ["gke-${var.cluster_name}"]
  }

  depends_on = [
    google_kms_crypto_key_iam_member.compute_agent,
    google_kms_crypto_key_iam_member.container_agent,
    google_project_iam_member.gke_node_logging,
    google_project_iam_member.gke_node_monitoring_metric,
    google_project_iam_member.gke_node_monitoring_viewer,
  ]
}
