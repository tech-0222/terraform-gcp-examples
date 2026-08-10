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

variable "zone" {
  description = "Zone for the VM."
  type        = string
  default     = "asia-northeast1-a"
}

variable "network_name" {
  description = "VPC network name."
  type        = string
  default     = "tf-example-gce-vpc"
}

variable "subnet_name" {
  description = "Subnet name."
  type        = string
  default     = "tf-example-gce-subnet"
}

variable "subnet_cidr" {
  description = "Subnet CIDR."
  type        = string
  default     = "10.20.0.0/24"
}

variable "instance_name" {
  description = "Compute Engine instance name."
  type        = string
  default     = "tf-example-gce-01"
}

variable "machine_type" {
  description = "Machine type. e2-medium or larger is recommended for general utility."
  type        = string
  default     = "e2-medium"
}
