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

variable "repository_id" {
  description = "Artifact Registry repository ID."
  type        = string
  default     = "tf-example-docker"
}

variable "description" {
  description = "Artifact Registry repository description."
  type        = string
  default     = "Docker repository for terraform-gcp-examples"
}
