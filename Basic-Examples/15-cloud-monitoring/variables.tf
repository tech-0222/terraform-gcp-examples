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

variable "alert_policy_name" {
  description = "Display name of the Cloud Monitoring alert policy."
  type        = string
  default     = "tf-example-gce-cpu-high"
}

variable "cpu_threshold" {
  description = "CPU utilization threshold as a ratio from 0 to 1."
  type        = number
  default     = 0.8

  validation {
    condition     = var.cpu_threshold > 0 && var.cpu_threshold <= 1
    error_message = "cpu_threshold must be greater than 0 and less than or equal to 1."
  }
}

variable "duration" {
  description = "How long the threshold must be violated before an incident is opened."
  type        = string
  default     = "300s"
}

variable "alignment_period" {
  description = "Alignment period used by the CPU utilization condition."
  type        = string
  default     = "300s"
}

variable "notification_email" {
  description = "Optional email address for a notification channel. Leave null to create only the alert policy."
  type        = string
  default     = null
}

variable "notification_channel_name" {
  description = "Display name of the optional email notification channel."
  type        = string
  default     = "tf-example-email"
}
