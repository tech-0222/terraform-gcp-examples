variable "project_id" {
  description = "Google Cloud Project ID."
  type        = string

  validation {
    condition     = length(trimspace(var.project_id)) > 0
    error_message = "project_id must not be empty."
  }
}

variable "region" {
  description = "Region for the subnet, Cloud Router, and Cloud NAT."
  type        = string
  default     = "asia-northeast1"
}

variable "zone" {
  description = "Zone for the test VM."
  type        = string
  default     = "asia-northeast1-a"
}

variable "network_name" {
  description = "VPC network name."
  type        = string
  default     = "tf-adv-iap-forward-vpc"
}

variable "subnet_name" {
  description = "Subnet name."
  type        = string
  default     = "tf-adv-iap-forward-subnet"
}

variable "subnet_cidr" {
  description = "Subnet primary IPv4 CIDR."
  type        = string
  default     = "10.70.0.0/24"
}

variable "instance_name" {
  description = "Compute Engine instance name."
  type        = string
  default     = "tf-adv-iap-forward-vm"
}

variable "machine_type" {
  description = "Machine type for the short-lived test VM."
  type        = string
  default     = "e2-small"
}

variable "local_port" {
  description = "Local IPv4 port used by the generated SSH forwarding command."
  type        = number
  default     = 8080

  validation {
    condition     = var.local_port >= 1024 && var.local_port <= 65535
    error_message = "local_port must be between 1024 and 65535."
  }
}

variable "iap_member" {
  description = "IAM member granted IAP tunnel and OS Login (for example, user:you@example.com)."
  type        = string

  validation {
    condition     = can(regex("^(user|serviceAccount|group):.+", var.iap_member))
    error_message = "iap_member must look like user:email, serviceAccount:email, or group:email."
  }
}
