output "project_id" {
  description = "Google Cloud Project ID."
  value       = var.project_id
}

output "location" {
  description = "Deployment region."
  value       = var.region
}

output "service_name" {
  description = "Cloud Run service name."
  value       = google_cloud_run_v2_service.app.name
}

output "service_url" {
  description = "Cloud Run service URI."
  value       = google_cloud_run_v2_service.app.uri
}

output "runtime_service_account" {
  description = "Cloud Run runtime service account email."
  value       = google_service_account.run.email
}

output "sql_instance_name" {
  description = "Cloud SQL instance name."
  value       = google_sql_database_instance.postgres.name
}

output "instance_connection_name" {
  description = "Cloud SQL connection name used by Cloud Run."
  value       = google_sql_database_instance.postgres.connection_name
}

output "database_name" {
  description = "Application database name."
  value       = google_sql_database.app.name
}

output "database_user" {
  description = "Application database user."
  value       = google_sql_user.app.name
}

output "secret_id" {
  description = "Secret Manager secret ID containing the database password."
  value       = google_secret_manager_secret.db_password.secret_id
}

output "repository_url" {
  description = "Artifact Registry Docker repository URL."
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.app.repository_id}"
}

output "app_image_example" {
  description = "Suggested image URI for the bundled sample app."
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.app.repository_id}/cloudrun-sql:latest"
}

output "curl_authenticated_example" {
  description = "Example authenticated request command."
  value       = "curl -H \"Authorization: Bearer $(gcloud auth print-identity-token)\" \"${google_cloud_run_v2_service.app.uri}\""
}
