variable "project_id" {
  description = "Google Cloud Project ID."
  type        = string

  validation {
    condition     = length(trimspace(var.project_id)) > 0
    error_message = "project_id must not be empty."
  }
}

variable "region" {
  description = "Region for the Cloud Run service."
  type        = string
  default     = "asia-northeast1"
}

variable "service_name" {
  description = "Cloud Run service name."
  type        = string
  default     = "tf-example-hello"
}

variable "container_image" {
  description = "Container image URL."
  type        = string
  default     = "us-docker.pkg.dev/cloudrun/container/hello"
}

variable "allow_unauthenticated" {
  description = "If true, grant roles/run.invoker to allUsers (public access)."
  type        = bool
  default     = true
}
