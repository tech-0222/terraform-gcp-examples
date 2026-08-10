output "project_id" {
  description = "Google Cloud Project ID."
  value       = var.project_id
}

output "dataset_id" {
  description = "BigQuery dataset ID."
  value       = google_bigquery_dataset.example.dataset_id
}

output "table_id" {
  description = "BigQuery table ID."
  value       = google_bigquery_table.example.table_id
}

output "dataset_reference" {
  description = "Dataset reference usable with the bq CLI."
  value       = "${var.project_id}:${google_bigquery_dataset.example.dataset_id}"
}

output "table_reference" {
  description = "Table reference usable with the bq CLI."
  value       = "${var.project_id}:${google_bigquery_dataset.example.dataset_id}.${google_bigquery_table.example.table_id}"
}
