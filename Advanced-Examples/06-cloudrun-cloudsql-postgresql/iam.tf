# Dedicated runtime identity for Cloud Run.
resource "google_service_account" "run" {
  project      = var.project_id
  account_id   = "tf-adv-run-sql"
  display_name = "Advanced Cloud Run SQL runtime"
  description  = "Runtime SA for Advanced-Examples/06-cloudrun-cloudsql-postgresql."

  depends_on = [google_project_service.required]
}

# Cloud Run must be allowed to connect to Cloud SQL.
resource "google_project_iam_member" "run_cloudsql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.run.email}"
}

# Keep Secret Manager access scoped to this secret rather than the whole project.
resource "google_secret_manager_secret_iam_member" "run_secret_accessor" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.db_password.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.run.email}"
}

# Keep image-read permission scoped to this Artifact Registry repository.
resource "google_artifact_registry_repository_iam_member" "run_reader" {
  project    = var.project_id
  location   = google_artifact_registry_repository.app.location
  repository = google_artifact_registry_repository.app.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.run.email}"
}

# Optional authenticated invoker.
resource "google_cloud_run_v2_service_iam_member" "invoker" {
  count = trimspace(var.invoker_member) != "" ? 1 : 0

  project  = google_cloud_run_v2_service.app.project
  location = google_cloud_run_v2_service.app.location
  name     = google_cloud_run_v2_service.app.name
  role     = "roles/run.invoker"
  member   = var.invoker_member
}

# Optional public access (disabled by default).
resource "google_cloud_run_v2_service_iam_member" "public" {
  count = var.allow_unauthenticated ? 1 : 0

  project  = google_cloud_run_v2_service.app.project
  location = google_cloud_run_v2_service.app.location
  name     = google_cloud_run_v2_service.app.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
