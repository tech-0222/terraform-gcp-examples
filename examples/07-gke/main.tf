# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_project_service
resource "google_project_service" "required" {
  for_each = toset([
    "container.googleapis.com",
    "compute.googleapis.com",
  ])

  project = var.project_id
  service = each.value

  disable_on_destroy = false
}

# Zonal Standard cluster (cost-conscious learning sample).
# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_cluster
resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.zone

  network    = google_compute_network.vpc.name
  subnetwork = google_compute_subnetwork.primary.name

  # Create a throwaway default pool then replace with Spot node pool.
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

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  resource_labels = {
    env        = "test"
    system     = "tf-examples"
    component  = "gke"
    managed_by = "terraform"
    example    = "07-gke"
  }
}

# Spot node pool: cheaper, but nodes can be reclaimed.
# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_node_pool
resource "google_container_node_pool" "spot" {
  name     = "spot-pool"
  location = var.zone
  cluster  = google_container_cluster.primary.name

  node_count = var.node_count

  node_config {
    machine_type = var.machine_type
    spot         = true
    disk_size_gb = 30
    disk_type    = "pd-balanced"

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]

    metadata = {
      disable-legacy-endpoints = "true"
    }

    labels = {
      env        = "test"
      system     = "tf-examples"
      component  = "gke"
      managed_by = "terraform"
      example    = "07-gke"
    }

    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }
}
