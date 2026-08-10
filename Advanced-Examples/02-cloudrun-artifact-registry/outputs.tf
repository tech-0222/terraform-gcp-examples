output "repository_id" {
  description = "Artifact Registry repository ID."
  value       = google_artifact_registry_repository.app.repository_id
}

output "repository_url" {
  description = "Docker repository host/path prefix (without image name)."
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.app.repository_id}"
}

output "service_name" {
  description = "Cloud Run service name."
  value       = google_cloud_run_v2_service.hello.name
}

output "uri" {
  description = "Cloud Run service URI."
  value       = google_cloud_run_v2_service.hello.uri
}

output "location" {
  description = "Cloud Run location."
  value       = google_cloud_run_v2_service.hello.location
}

output "runtime_service_account_email" {
  description = "Cloud Run runtime service account email."
  value       = google_service_account.run.email
}

output "example_ar_image" {
  description = "Example image path after pushing hello into Artifact Registry."
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.app.repository_id}/hello:latest"
}

output "curl_authenticated_example" {
  description = "Example authenticated request (requires roles/run.invoker)."
  value       = "curl -sS -H \"Authorization: Bearer $(gcloud auth print-identity-token)\" \"${google_cloud_run_v2_service.hello.uri}\""
}
