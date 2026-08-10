# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_project_service
resource "google_project_service" "secretmanager" {
  project = var.project_id
  service = "secretmanager.googleapis.com"

  disable_on_destroy = false
}

# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret
resource "google_secret_manager_secret" "example" {
  secret_id = var.secret_id

  replication {
    auto {}
  }

  labels = {
    env        = "test"
    system     = "tf-examples"
    component  = "secret-manager"
    managed_by = "terraform"
    example    = "09-secret-manager"
  }

  depends_on = [google_project_service.secretmanager]
}

# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret_version
resource "google_secret_manager_secret_version" "example" {
  secret                 = google_secret_manager_secret.example.id
  secret_data_wo         = var.secret_data
  secret_data_wo_version = var.secret_data_version
}
