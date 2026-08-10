# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_project_service
resource "google_project_service" "required" {
  for_each = toset([
    "run.googleapis.com",
    "artifactregistry.googleapis.com",
    "iam.googleapis.com",
  ])

  project = var.project_id
  service = each.value

  disable_on_destroy = false
}

# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/artifact_registry_repository
resource "google_artifact_registry_repository" "app" {
  location      = var.region
  repository_id = var.repository_id
  description   = "Advanced example images for Cloud Run"
  format        = "DOCKER"

  labels = {
    env        = "test"
    system     = "tf-examples"
    component  = "artifact-registry"
    managed_by = "terraform"
    example    = "02-cloudrun-artifact-registry"
  }

  depends_on = [google_project_service.required]
}

# Runtime identity for Cloud Run (pulls images / calls Google APIs without SA keys).
# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_service_account
resource "google_service_account" "run" {
  account_id   = "tf-adv-run-runtime"
  display_name = "Advanced Cloud Run runtime"
  description  = "Runtime SA for Advanced-Examples/02-cloudrun-artifact-registry."

  depends_on = [google_project_service.required]
}

# Allow the Cloud Run runtime SA to read images from this repository.
# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/artifact_registry_repository_iam
resource "google_artifact_registry_repository_iam_member" "run_reader" {
  project    = var.project_id
  location   = google_artifact_registry_repository.app.location
  repository = google_artifact_registry_repository.app.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.run.email}"
}

# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloud_run_v2_service
resource "google_cloud_run_v2_service" "hello" {
  name     = var.service_name
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"

  deletion_protection = false

  template {
    service_account = google_service_account.run.email

    containers {
      image = var.container_image

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }
    }

    scaling {
      min_instance_count = 0
      max_instance_count = 2
    }
  }

  labels = {
    env        = "test"
    system     = "tf-examples"
    component  = "cloudrun"
    managed_by = "terraform"
    example    = "02-cloudrun-artifact-registry"
  }

  depends_on = [
    google_project_service.required,
    google_artifact_registry_repository_iam_member.run_reader,
  ]
}

# Authenticated invoker (preferred for this advanced sample).
# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloud_run_v2_service_iam
resource "google_cloud_run_v2_service_iam_member" "invoker" {
  count = trimspace(var.invoker_member) != "" ? 1 : 0

  project  = google_cloud_run_v2_service.hello.project
  location = google_cloud_run_v2_service.hello.location
  name     = google_cloud_run_v2_service.hello.name
  role     = "roles/run.invoker"
  member   = var.invoker_member
}

# Optional public access (disabled by default).
resource "google_cloud_run_v2_service_iam_member" "public" {
  count = var.allow_unauthenticated ? 1 : 0

  project  = google_cloud_run_v2_service.hello.project
  location = google_cloud_run_v2_service.hello.location
  name     = google_cloud_run_v2_service.hello.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
