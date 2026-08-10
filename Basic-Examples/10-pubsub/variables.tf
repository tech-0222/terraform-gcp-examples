variable "project_id" {
  description = "Google Cloud Project ID."
  type        = string

  validation {
    condition     = length(trimspace(var.project_id)) > 0
    error_message = "project_id must not be empty."
  }
}

variable "region" {
  description = "Default region for the provider."
  type        = string
  default     = "asia-northeast1"
}

variable "topic_name" {
  description = "Pub/Sub topic name."
  type        = string
  default     = "tf-example-topic"
}

variable "subscription_name" {
  description = "Pub/Sub pull subscription name."
  type        = string
  default     = "tf-example-subscription"
}

variable "ack_deadline_seconds" {
  description = "Initial acknowledgement deadline for pulled messages."
  type        = number
  default     = 20

  validation {
    condition     = var.ack_deadline_seconds >= 10 && var.ack_deadline_seconds <= 600
    error_message = "ack_deadline_seconds must be between 10 and 600."
  }
}
