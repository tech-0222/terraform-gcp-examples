# A Cloud Billing budget, and somewhere for its notifications to land.
#
# Two things about budgets are easy to get wrong:
#
#   1. A budget does not belong to a project. It belongs to a billing account,
#      which is outside the project hierarchy. `gcloud projects` will never
#      show it and deleting the project does not remove it.
#   2. A budget does not stop anything. Reaching 100% sends a notification and
#      nothing else -- the resources keep running and the bill keeps growing.
#
# The PoC this came from left notifications to the billing account's default
# email, so there was no way to see what a notification actually contains.
# Here they go to Pub/Sub, where they can be pulled and read.

resource "google_project_service" "required" {
  for_each = toset([
    "billingbudgets.googleapis.com",
    "cloudbilling.googleapis.com",
    "pubsub.googleapis.com",
  ])

  project = var.project_id
  service = each.value

  disable_on_destroy = false
}

# budget_filter.projects wants "projects/<number>", not the project ID.
# Ref: https://cloud.google.com/billing/docs/reference/budget/rest/v1/billingAccounts.budgets
data "google_project" "scope" {
  project_id = var.project_id
}

resource "google_pubsub_topic" "budget" {
  name = var.topic_name

  labels = {
    env        = "test"
    system     = "tf-examples"
    managed_by = "terraform"
    example    = "26-billing-budget-pubsub"
  }

  depends_on = [google_project_service.required]
}

# A pull subscription so the notification can be read from a terminal. In
# production this would be push, to a function or a webhook.
resource "google_pubsub_subscription" "budget" {
  name  = "${var.topic_name}-sub"
  topic = google_pubsub_topic.budget.id

  # Long enough to still be there when the periodic notification arrives,
  # short enough that nothing lingers after destroy.
  message_retention_duration = "600s"
  ack_deadline_seconds       = 20

  labels = {
    env        = "test"
    system     = "tf-examples"
    managed_by = "terraform"
    example    = "26-billing-budget-pubsub"
  }
}

# No explicit publisher grant here, deliberately.
#
# Guides commonly say to grant roles/pubsub.publisher to a billing service
# agent. Three of the addresses that circulate do not exist:
#
#   billing-budgets@system.gserviceaccount.com
#   billing-budgets-pubsub@system.gserviceaccount.com
#   cloud-billing-budgets@system.gserviceaccount.com
#
# All three fail with "Service account ... does not exist". Cloud Billing
# arranges publish access itself when all_updates_rule.pubsub_topic is set,
# so the topic needs no binding of ours. See the README for the measurement.

# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/billing_budget
resource "google_billing_budget" "main" {
  billing_account = var.billing_account_id
  display_name    = var.budget_display_name

  budget_filter {
    projects               = ["projects/${data.google_project.scope.number}"]
    calendar_period        = var.calendar_period
    credit_types_treatment = var.credit_types_treatment

    # Only spend carrying these labels counts. An empty map covers the whole
    # project. The API accepts a single key here, not several.
    labels = var.budget_labels
  }

  amount {
    specified_amount {
      currency_code = var.currency_code
      units         = tostring(var.budget_amount_units)
    }
  }

  # Two rules on purpose: CURRENT_SPEND fires on money already spent,
  # FORECASTED_SPEND fires on the projection for the period. They answer
  # different questions and both are usually wanted.
  dynamic "threshold_rules" {
    for_each = var.threshold_rules
    content {
      threshold_percent = threshold_rules.value.threshold_percent
      spend_basis       = threshold_rules.value.spend_basis
    }
  }

  all_updates_rule {
    pubsub_topic = google_pubsub_topic.budget.id

    # 1.0 is the only value the API accepts here.
    schema_version = "1.0"
  }

  depends_on = [google_pubsub_subscription.budget]
}
