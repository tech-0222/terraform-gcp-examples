output "enabled_services" {
  description = "API service names managed by this sample."
  value       = sort([for s in google_project_service.apis : s.service])
}

output "project_id" {
  description = "Google Cloud Project ID where APIs were enabled."
  value       = var.project_id
}
