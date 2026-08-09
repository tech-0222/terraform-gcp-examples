output "repository_id" {
  description = "Artifact Registry repository ID."
  value       = google_artifact_registry_repository.example.repository_id
}

output "repository_name" {
  description = "Full Artifact Registry repository resource name."
  value       = google_artifact_registry_repository.example.name
}

output "docker_repository_url" {
  description = "Docker repository hostname/path."
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.example.repository_id}"
}
