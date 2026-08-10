variable "project_id" {
  description = "Google Cloud Project ID."
  type        = string

  validation {
    condition     = length(trimspace(var.project_id)) > 0
    error_message = "project_id must not be empty."
  }
}

variable "region" {
  description = "Cloud SQL region."
  type        = string
  default     = "asia-northeast1"
}

variable "instance_name" {
  description = "Cloud SQL instance name."
  type        = string
  default     = "tf-example-postgres"
}

variable "database_name" {
  description = "PostgreSQL database name."
  type        = string
  default     = "appdb"
}

variable "database_version" {
  description = "Cloud SQL PostgreSQL version."
  type        = string
  default     = "POSTGRES_15"
}

variable "tier" {
  description = "Cloud SQL machine tier. Shared-core is used to keep the learning sample small."
  type        = string
  default     = "db-f1-micro"
}

variable "disk_size_gb" {
  description = "Initial SSD size in GB."
  type        = number
  default     = 10

  validation {
    condition     = var.disk_size_gb >= 10
    error_message = "disk_size_gb must be at least 10 GB."
  }
}
