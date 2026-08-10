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
  description = "Prefix for the Terraform state bucket. Final name is <prefix>-<project_id>."
  type        = string
  default     = "tf-adv-tfstate"
}

variable "location" {
  description = "Bucket location."
  type        = string
  default     = "ASIA-NORTHEAST1"
}

variable "force_destroy" {
  description = "Allow destroy even when the bucket still has objects (learning sample)."
  type        = bool
  default     = true
}
