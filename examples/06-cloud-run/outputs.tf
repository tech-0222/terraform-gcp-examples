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
