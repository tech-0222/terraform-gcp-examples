output "state_bucket_name" {
  description = "GCS bucket name for Terraform remote state."
  value       = google_storage_bucket.tfstate.name
}

output "state_bucket_url" {
  description = "GCS URL of the state bucket."
  value       = google_storage_bucket.tfstate.url
}

output "backend_hcl_example" {
  description = "Example backend.hcl contents for the demo/ root module."
  value       = <<-EOT
    bucket = "${google_storage_bucket.tfstate.name}"
    prefix = "demo"
  EOT
}
