# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_project_service
resource "google_project_service" "pubsub" {
  project = var.project_id
  service = "pubsub.googleapis.com"

  disable_on_destroy = false
}

# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/pubsub_topic
resource "google_pubsub_topic" "example" {
  name = var.topic_name

  labels = {
    env        = "test"
    system     = "tf-examples"
    component  = "pubsub"
    managed_by = "terraform"
    example    = "10-pubsub"
  }

  depends_on = [google_project_service.pubsub]
}

# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/pubsub_subscription
resource "google_pubsub_subscription" "example" {
  name  = var.subscription_name
  topic = google_pubsub_topic.example.id

  ack_deadline_seconds = var.ack_deadline_seconds

  labels = {
    env        = "test"
    system     = "tf-examples"
    component  = "pubsub"
    managed_by = "terraform"
    example    = "10-pubsub"
  }
}
