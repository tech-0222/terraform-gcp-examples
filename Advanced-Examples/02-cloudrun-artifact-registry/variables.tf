variable "project_id" {
  description = "Google Cloud Project ID."
  type        = string

  validation {
    condition     = length(trimspace(var.project_id)) > 0
    error_message = "project_id must not be empty."
  }
}

variable "region" {
  description = "Region for Artifact Registry and Cloud Run."
  type        = string
  default     = "asia-northeast1"
}

variable "repository_id" {
  description = "Artifact Registry repository ID."
  type        = string
  default     = "tf-adv-run"
}

variable "service_name" {
  description = "Cloud Run service name."
  type        = string
  default     = "tf-adv-hello"
}

variable "container_image" {
  description = "Container image URL. Prefer an image in this project's Artifact Registry after push."
  type        = string
  # Public hello image so the first apply succeeds before you push to AR.
  default = "us-docker.pkg.dev/cloudrun/container/hello"
}

variable "invoker_member" {
  description = "IAM member granted roles/run.invoker (e.g. user:you@example.com). Empty skips the binding."
  type        = string
  default     = ""
}

variable "allow_unauthenticated" {
  description = "If true, grant roles/run.invoker to allUsers (not recommended for this advanced sample)."
  type        = bool
  default     = false
}
