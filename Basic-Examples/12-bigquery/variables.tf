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

variable "location" {
  description = "BigQuery dataset location."
  type        = string
  default     = "asia-northeast1"
}

variable "dataset_id" {
  description = "BigQuery dataset ID."
  type        = string
  default     = "tf_example_dataset"

  validation {
    condition     = can(regex("^[A-Za-z0-9_]+$", var.dataset_id))
    error_message = "dataset_id may contain only letters, numbers, and underscores."
  }
}

variable "table_id" {
  description = "BigQuery table ID."
  type        = string
  default     = "messages"

  validation {
    condition     = can(regex("^[A-Za-z0-9_]+$", var.table_id))
    error_message = "table_id may contain only letters, numbers, and underscores."
  }
}

variable "delete_contents_on_destroy" {
  description = "Allow Terraform to delete the dataset even when it contains tables. Learning use only."
  type        = bool
  default     = true
}
