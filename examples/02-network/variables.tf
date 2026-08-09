variable "project_id" {
  description = "Google Cloud Project ID."
  type        = string

  validation {
    condition     = length(trimspace(var.project_id)) > 0
    error_message = "project_id must not be empty."
  }
}

variable "region" {
  description = "Region for the subnet."
  type        = string
  default     = "asia-northeast1"
}

variable "network_name" {
  description = "VPC network name."
  type        = string
  default     = "tf-example-vpc"
}

variable "subnet_name" {
  description = "Subnet name."
  type        = string
  default     = "tf-example-subnet"
}

variable "subnet_cidr" {
  description = "Primary IPv4 CIDR for the subnet."
  type        = string
  default     = "10.10.0.0/24"
}
