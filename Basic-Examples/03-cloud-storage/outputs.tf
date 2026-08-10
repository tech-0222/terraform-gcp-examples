output "bucket_name" {
  description = "Cloud Storage bucket name."
  value       = google_storage_bucket.example.name
}

output "bucket_url" {
  description = "gs:// URL of the bucket."
  value       = google_storage_bucket.example.url
}

output "bucket_self_link" {
  description = "Bucket self link."
  value       = google_storage_bucket.example.self_link
}

output "location" {
  description = "Bucket location."
  value       = google_storage_bucket.example.location
}
