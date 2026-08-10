output "secret_id" {
  description = "Secret Manager secret ID."
  value       = google_secret_manager_secret.example.secret_id
}

output "secret_name" {
  description = "Full resource name of the secret."
  value       = google_secret_manager_secret.example.id
}

output "secret_version" {
  description = "Created Secret Manager version number."
  value       = google_secret_manager_secret_version.example.version
}
