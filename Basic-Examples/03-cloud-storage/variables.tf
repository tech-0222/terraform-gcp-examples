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

variable "bucket_name_prefix" {
  description = "Prefix for the bucket name. Final name is <prefix>-<project_id> (must be globally unique)."
  type        = string
  default     = "tf-example"
}

variable "location" {
  description = "Bucket location."
  type        = string
  default     = "ASIA-NORTHEAST1"
}

variable "force_destroy" {
  description = "If true, allow terraform destroy even when the bucket is not empty."
  type        = bool
  default     = true
}
