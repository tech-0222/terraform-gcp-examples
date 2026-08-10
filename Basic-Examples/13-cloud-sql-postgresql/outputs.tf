output "project_id" {
  description = "Google Cloud Project ID."
  value       = var.project_id
}

output "instance_name" {
  description = "Cloud SQL instance name."
  value       = google_sql_database_instance.example.name
}

output "connection_name" {
  description = "Cloud SQL connection name."
  value       = google_sql_database_instance.example.connection_name
}

output "public_ip_address" {
  description = "Public IPv4 address of the instance. No authorized network is configured by this sample."
  value       = google_sql_database_instance.example.public_ip_address
}

output "database_name" {
  description = "PostgreSQL database name."
  value       = google_sql_database.example.name
}
