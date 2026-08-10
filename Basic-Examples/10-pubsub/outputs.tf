output "topic_name" {
  description = "Pub/Sub topic name."
  value       = google_pubsub_topic.example.name
}

output "subscription_name" {
  description = "Pub/Sub subscription name."
  value       = google_pubsub_subscription.example.name
}

output "publish_example" {
  description = "Example command to publish a test message."
  value       = "gcloud pubsub topics publish ${google_pubsub_topic.example.name} --message='hello-terraform' --project=${var.project_id}"
}

output "pull_example" {
  description = "Example command to pull one message."
  value       = "gcloud pubsub subscriptions pull ${google_pubsub_subscription.example.name} --limit=1 --auto-ack --project=${var.project_id}"
}
