variable "project_id" {
  description = "Google Cloud Project ID where APIs are enabled."
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

variable "services" {
  description = "Google Cloud API service names to enable. See https://cloud.google.com/service-usage/docs/enabled-service"
  type        = set(string)
  default = [
    "compute.googleapis.com",
    "iam.googleapis.com",
    "storage.googleapis.com",
  ]

  validation {
    condition     = length(var.services) > 0
    error_message = "services must contain at least one API."
  }
}

variable "disable_on_destroy" {
  description = "If true, terraform destroy disables the APIs. If false, APIs remain enabled after destroy."
  type        = bool
  default     = false
}

variable "disable_dependent_services" {
  description = "If true, disable services that depend on the target APIs when disabling. Use carefully."
  type        = bool
  default     = false
}
