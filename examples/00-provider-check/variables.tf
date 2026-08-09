variable "project_id" {
  description = "Google Cloud Project ID used for the test."
  type        = string

  validation {
    condition     = length(trimspace(var.project_id)) > 0
    error_message = "project_id must not be empty."
  }
}

variable "region" {
  description = "Default Google Cloud region used by the provider."
  type        = string
  default     = "asia-northeast1"
}
