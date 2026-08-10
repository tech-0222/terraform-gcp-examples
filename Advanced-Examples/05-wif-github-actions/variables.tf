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

variable "pool_id" {
  description = "Workload Identity Pool ID."
  type        = string
  default     = "tf-adv-github-pool"
}

variable "provider_id" {
  description = "Workload Identity Pool Provider ID (GitHub OIDC)."
  type        = string
  default     = "tf-adv-github-provider"
}

variable "service_account_id" {
  description = "Service Account ID used by GitHub Actions via WIF."
  type        = string
  default     = "tf-adv-github-actions"
}

variable "github_repository" {
  description = "GitHub repository allowed to impersonate the SA (org/repo)."
  type        = string
  default     = "tech-0222/terraform-gcp-examples"

  validation {
    condition     = can(regex("^[^/]+/[^/]+$", var.github_repository))
    error_message = "github_repository must be in org/repo form."
  }
}

variable "demo_bucket_prefix" {
  description = "Prefix for a tiny bucket used to demonstrate least-privilege access from GHA."
  type        = string
  default     = "tf-adv-wif-demo"
}
