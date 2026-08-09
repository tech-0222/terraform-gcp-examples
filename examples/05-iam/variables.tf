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

variable "service_account_id" {
  description = "Service Account ID (account_id), 6-30 chars."
  type        = string
  default     = "tf-example-sa"
}

variable "service_account_display_name" {
  description = "Service Account display name."
  type        = string
  default     = "TF Example Service Account"
}

variable "project_iam_role" {
  description = "Project-level IAM role granted to the Service Account (least privilege example)."
  type        = string
  default     = "roles/storage.objectViewer"
}
