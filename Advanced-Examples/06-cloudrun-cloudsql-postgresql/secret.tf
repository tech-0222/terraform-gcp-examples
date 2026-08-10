# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret
resource "google_secret_manager_secret" "db_password" {
  project   = var.project_id
  secret_id = var.secret_id

  replication {
    auto {}
  }

  labels = {
    env        = "test"
    system     = "tf-examples"
    component  = "secret-manager"
    managed_by = "terraform"
    example    = "06-cloudrun-cloudsql-postgresql"
  }

  depends_on = [google_project_service.required]
}

# Terraform 1.11+ write-only argument: secret value is not persisted in raw plan/state.
# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret_version
resource "google_secret_manager_secret_version" "db_password" {
  secret                 = google_secret_manager_secret.db_password.id
  secret_data_wo         = var.db_password
  secret_data_wo_version = var.db_password_version
}
