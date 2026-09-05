variable "project_id" {
  description = "Google Cloud Project ID. The budget scopes to this project's spend."
  type        = string

  validation {
    condition     = length(trimspace(var.project_id)) > 0
    error_message = "project_id must not be empty."
  }
}

variable "region" {
  description = "Region for the Pub/Sub resources."
  type        = string
  default     = "asia-northeast1"
}

variable "billing_account_id" {
  description = "Billing account the budget belongs to (e.g. 012345-6789AB-CDEF01). Note that the budget lives here, NOT in the project -- deleting the project does not remove it. Find it with `gcloud billing accounts list`."
  type        = string

  validation {
    condition     = can(regex("^[0-9A-F]{6}-[0-9A-F]{6}-[0-9A-F]{6}$", var.billing_account_id))
    error_message = "billing_account_id must look like 012345-6789AB-CDEF01."
  }
}

variable "budget_display_name" {
  description = "Name shown in the console. Budgets are not namespaced by project, so make it identifiable."
  type        = string
  default     = "tf-adv-budget-pubsub"
}

variable "budget_amount_units" {
  description = "Budget amount in whole currency units. This is a notification threshold, not a spending cap -- exceeding it stops nothing."
  type        = number
  default     = 1
}

variable "currency_code" {
  description = "Currency. Must match the billing account's currency."
  type        = string
  default     = "JPY"
}

variable "calendar_period" {
  description = "Period the spend is accumulated over. MONTH resets on the first of each month."
  type        = string
  default     = "MONTH"
}

variable "credit_types_treatment" {
  description = "How credits count toward the threshold. INCLUDE_ALL_CREDITS subtracts them, so free-tier usage lowers the apparent spend; EXCLUDE_ALL_CREDITS shows list price."
  type        = string
  default     = "INCLUDE_ALL_CREDITS"
}

variable "budget_labels" {
  description = "Restrict the budget to spend carrying this label. An empty map covers the whole project. The API accepts one key, not several."
  type        = map(string)
  default     = {}
}

variable "threshold_rules" {
  description = "When to notify. CURRENT_SPEND fires on money already spent; FORECASTED_SPEND fires on the projection for the period. They answer different questions."
  type = list(object({
    threshold_percent = number
    spend_basis       = string
  }))
  default = [
    { threshold_percent = 0.5, spend_basis = "CURRENT_SPEND" },
    { threshold_percent = 1.0, spend_basis = "CURRENT_SPEND" },
    { threshold_percent = 1.0, spend_basis = "FORECASTED_SPEND" },
  ]
}

variable "topic_name" {
  description = "Pub/Sub topic the budget publishes to."
  type        = string
  default     = "tf-adv-budget-notifications"
}
