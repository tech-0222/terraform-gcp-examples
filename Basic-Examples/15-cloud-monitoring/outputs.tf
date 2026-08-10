output "project_id" {
  description = "Google Cloud Project ID."
  value       = var.project_id
}

output "alert_policy_name" {
  description = "Cloud Monitoring alert policy display name."
  value       = google_monitoring_alert_policy.cpu_usage.display_name
}

output "alert_policy_id" {
  description = "Cloud Monitoring alert policy resource ID."
  value       = google_monitoring_alert_policy.cpu_usage.id
}

output "notification_channel_name" {
  description = "Notification channel resource name, or null when notification_email is not set."
  value       = length(google_monitoring_notification_channel.email) > 0 ? google_monitoring_notification_channel.email[0].name : null
}
