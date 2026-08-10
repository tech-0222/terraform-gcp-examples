output "project_number" {
  description = "Project number (needed in WIF provider resource name)."
  value       = data.google_project.current.number
}

output "workload_identity_pool_id" {
  description = "Full Workload Identity Pool resource name."
  value       = google_iam_workload_identity_pool.github.name
}

output "workload_identity_provider_name" {
  description = "Full WIF provider resource name for google-github-actions/auth."
  value       = google_iam_workload_identity_pool_provider.github.name
}

output "service_account_email" {
  description = "Service account email for GitHub Actions."
  value       = google_service_account.github.email
}

output "demo_bucket_name" {
  description = "Demo bucket the workflow can list/read."
  value       = google_storage_bucket.demo.name
}

output "github_repository" {
  description = "GitHub repository allowed by attribute_condition / IAM principalSet."
  value       = var.github_repository
}

output "auth_action_inputs_example" {
  description = "Example inputs for google-github-actions/auth."
  value       = <<-EOT
    workload_identity_provider: "${google_iam_workload_identity_pool_provider.github.name}"
    service_account: "${google_service_account.github.email}"
  EOT
}
