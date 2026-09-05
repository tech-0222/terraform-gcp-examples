output "project_id" {
  description = "Google Cloud Project ID."
  value       = var.project_id
}

output "budget_name" {
  description = "Full resource name. Note the billingAccounts/ prefix: this is not a project resource."
  value       = google_billing_budget.main.name
}

output "scoped_project_number" {
  description = "budget_filter.projects needs the project NUMBER, not the ID."
  value       = data.google_project.scope.number
}

output "topic_name" {
  description = "Pub/Sub topic receiving budget notifications."
  value       = google_pubsub_topic.budget.name
}

output "subscription_name" {
  description = "Pull subscription for reading the notifications."
  value       = google_pubsub_subscription.budget.name
}

output "pull_notification_example" {
  description = "Read a budget notification. They arrive on a schedule, not only when a threshold is crossed, so this returns something even below the limit."
  value       = "gcloud pubsub subscriptions pull ${google_pubsub_subscription.budget.name} --auto-ack --limit=5 --format=json --project=${var.project_id}"
}

output "list_budgets_example" {
  description = "Budgets are not visible through `gcloud projects`. They are listed per billing account."
  value       = "gcloud billing budgets list --billing-account=${var.billing_account_id}"
}
