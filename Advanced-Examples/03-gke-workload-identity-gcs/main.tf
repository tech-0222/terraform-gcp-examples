locals {
  bucket_name = "${var.bucket_name_prefix}-${var.project_id}"
  wi_member   = "serviceAccount:${var.project_id}.svc.id.goog[${var.k8s_namespace}/${var.k8s_service_account}]"
}

# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_project_service
resource "google_project_service" "required" {
  for_each = toset([
    "container.googleapis.com",
    "compute.googleapis.com",
    "storage.googleapis.com",
    "iam.googleapis.com",
  ])

  project = var.project_id
  service = each.value

  disable_on_destroy = false
}

# GCP SA used by Pods via Workload Identity (no JSON keys).
# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_service_account
resource "google_service_account" "gcs" {
  account_id   = "tf-adv-gke-wi-gcs"
  display_name = "Advanced GKE WI GCS writer"
  description  = "Bound to KSA via Workload Identity for Advanced-Examples/03."

  depends_on = [google_project_service.required]
}

# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket
resource "google_storage_bucket" "demo" {
  name                        = local.bucket_name
  location                    = var.region
  force_destroy               = true
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  labels = {
    env        = "test"
    system     = "tf-examples"
    component  = "storage"
    managed_by = "terraform"
    example    = "03-gke-workload-identity-gcs"
  }

  depends_on = [google_project_service.required]
}

# Least privilege: object admin on this bucket only.
# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_iam
resource "google_storage_bucket_iam_member" "gcs_writer" {
  bucket = google_storage_bucket.demo.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.gcs.email}"
}

# Allow the Kubernetes SA to impersonate the GCP SA.
# Ref: https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity
# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_service_account_iam
resource "google_service_account_iam_member" "workload_identity_user" {
  service_account_id = google_service_account.gcs.name
  role               = "roles/iam.workloadIdentityUser"
  member             = local.wi_member
}

# Zonal Standard cluster with Workload Identity enabled.
# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_cluster
resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.zone

  network    = google_compute_network.vpc.name
  subnetwork = google_compute_subnetwork.primary.name

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
    example    = "03-gke-workload-identity-gcs"
  }
}

# Spot node pool (cheaper; nodes may be reclaimed).
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
      example    = "03-gke-workload-identity-gcs"
    }

    # Required for Workload Identity on nodes.
    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }
}
