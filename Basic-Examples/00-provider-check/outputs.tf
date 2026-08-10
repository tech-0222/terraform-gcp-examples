output "project_id" {
  description = "Google Cloud Project ID."
  value       = data.google_project.current.project_id
}

output "project_name" {
  description = "Google Cloud Project name."
  value       = data.google_project.current.name
}

output "project_number" {
  description = "Google Cloud Project number."
  value       = data.google_project.current.number
}
