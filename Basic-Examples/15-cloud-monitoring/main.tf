# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_project_service
resource "google_project_service" "monitoring" {
  project = var.project_id
  service = "monitoring.googleapis.com"

  disable_on_destroy = false
}

# The alert condition uses the Compute Engine CPU utilization metric.
resource "google_project_service" "compute" {
  project = var.project_id
  service = "compute.googleapis.com"

  disable_on_destroy = false
}

# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/monitoring_notification_channel
resource "google_monitoring_notification_channel" "email" {
  count = var.notification_email == null ? 0 : 1

  project      = var.project_id
  display_name = var.notification_channel_name
  type         = "email"
  enabled      = true

  labels = {
    email_address = coalesce(var.notification_email, "noreply@example.com")
  }

  depends_on = [google_project_service.monitoring]
}

# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/monitoring_alert_policy
resource "google_monitoring_alert_policy" "cpu_usage" {
  project      = var.project_id
  display_name = var.alert_policy_name
  combiner     = "OR"
  enabled      = true

  documentation {
    content   = "GCE CPU utilization exceeded the configured threshold for the configured duration."
    mime_type = "text/markdown"
  }

  conditions {
    display_name = "GCE CPU utilization threshold"

    condition_threshold {
      filter          = "resource.type = \"gce_instance\" AND metric.type = \"compute.googleapis.com/instance/cpu/utilization\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.cpu_threshold
      duration        = var.duration

      aggregations {
        alignment_period   = var.alignment_period
        per_series_aligner = "ALIGN_MEAN"
      }

      trigger {
        count = 1
      }
    }
  }

  notification_channels = google_monitoring_notification_channel.email[*].name

  user_labels = {
    env        = "test"
    system     = "tf-examples"
    component  = "monitoring"
    managed_by = "terraform"
    example    = "15-cloud-monitoring"
  }

  depends_on = [
    google_project_service.monitoring,
    google_project_service.compute,
  ]
}
