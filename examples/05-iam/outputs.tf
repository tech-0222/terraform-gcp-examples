output "service_account_email" {
  description = "Service Account email."
  value       = google_service_account.example.email
}

output "service_account_id" {
  description = "Service Account unique ID."
  value       = google_service_account.example.unique_id
}

output "service_account_name" {
  description = "Service Account resource name."
  value       = google_service_account.example.name
}

output "granted_role" {
  description = "IAM role granted to the Service Account on the project."
  value       = google_project_iam_member.example.role
}
