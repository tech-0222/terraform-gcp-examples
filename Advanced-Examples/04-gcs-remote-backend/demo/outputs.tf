output "demo_bucket_name" {
  description = "Demo bucket created while state lives in GCS."
  value       = google_storage_bucket.demo.name
}
