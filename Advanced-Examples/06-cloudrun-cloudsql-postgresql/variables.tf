variable "project_id" {
  description = "Google Cloud Project ID."
  type        = string
}

variable "region" {
  description = "Google Cloud region."
  type        = string
  default     = "asia-northeast1"
}

variable "service_name" {
  description = "Cloud Run service name."
  type        = string
  default     = "tf-adv-run-sql"
}

variable "repository_id" {
  description = "Artifact Registry Docker repository ID."
  type        = string
  default     = "tf-adv-run-sql"
}

variable "container_image" {
  description = "Container image for Cloud Run. Start with the public hello image, then replace it with the bundled app image."
  type        = string
  default     = "us-docker.pkg.dev/cloudrun/container/hello"
}

variable "instance_name" {
  description = "Cloud SQL for PostgreSQL instance name."
  type        = string
  default     = "tf-adv-run-sql-pg"
}

variable "database_version" {
  description = "Cloud SQL PostgreSQL version."
  type        = string
  default     = "POSTGRES_15"
}

variable "tier" {
  description = "Cloud SQL machine tier."
  type        = string
  default     = "db-f1-micro"
}

variable "disk_size_gb" {
  description = "Cloud SQL disk size in GB."
  type        = number
  default     = 10

  validation {
    condition     = var.disk_size_gb >= 10
    error_message = "disk_size_gb must be at least 10."
  }
}

variable "database_name" {
  description = "Application database name."
  type        = string
  default     = "appdb"
}

variable "db_user" {
  description = "Built-in PostgreSQL application user."
  type        = string
  default     = "appuser"
}

variable "db_password" {
  description = "Database password. Store the real value only in local terraform.tfvars."
  type        = string
  sensitive   = true
}

variable "db_password_version" {
  description = "Version trigger for write-only DB password arguments. Increment when db_password changes."
  type        = number
  default     = 1
}

variable "secret_id" {
  description = "Secret Manager secret ID used for the DB password."
  type        = string
  default     = "tf-adv-run-sql-db-password"
}

variable "invoker_member" {
  description = "Optional authenticated Cloud Run invoker, for example user:you@example.com. Empty disables the binding."
  type        = string
  default     = ""
}

variable "allow_unauthenticated" {
  description = "Allow public unauthenticated invocation. Disabled by default."
  type        = bool
  default     = false
}
