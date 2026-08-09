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

variable "secret_id" {
  description = "Secret Manager secret ID."
  type        = string
  default     = "tf-example-secret"
}

variable "secret_data" {
  description = "Secret value. This is passed to the provider via a write-only argument and is not stored in Terraform plan/state."
  type        = string
  sensitive   = true
}

variable "secret_data_version" {
  description = "Version trigger for the write-only secret value. Increment when secret_data changes."
  type        = number
  default     = 1
}
