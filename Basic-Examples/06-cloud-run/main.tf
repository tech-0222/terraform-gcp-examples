# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_project_service
resource "google_project_service" "required" {
  for_each = toset([
    "run.googleapis.com",
    "iam.googleapis.com",
  ])

  project = var.project_id
  service = each.value

  disable_on_destroy = false
}

# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloud_run_v2_service
resource "google_cloud_run_v2_service" "hello" {
  name     = var.service_name
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"

  # Allow destroy in learning samples without extra steps.
  deletion_protection = false

  template {
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
    example    = "06-cloud-run"
  }

  depends_on = [google_project_service.required]
}

# Public invoke for demo access. Set allow_unauthenticated=false for private services.
# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloud_run_v2_service_iam
resource "google_cloud_run_v2_service_iam_member" "public" {
  count = var.allow_unauthenticated ? 1 : 0

  project  = google_cloud_run_v2_service.hello.project
  location = google_cloud_run_v2_service.hello.location
  name     = google_cloud_run_v2_service.hello.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
