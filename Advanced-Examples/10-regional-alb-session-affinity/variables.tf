variable "project_id" {
  description = "Google Cloud Project ID."
  type        = string

  validation {
    condition     = length(trimspace(var.project_id)) > 0
    error_message = "project_id must not be empty."
  }
}

variable "region" {
  description = "Region for the regional external Application Load Balancer."
  type        = string
  default     = "asia-northeast1"
}

variable "zone" {
  description = "Zone for both backends (needed so one NEG can hold two endpoints)."
  type        = string
  default     = "asia-northeast1-a"
}

variable "network_name" {
  description = "VPC network name."
  type        = string
  default     = "tf-adv-elb10-vpc"
}

variable "subnet_name" {
  description = "Workload subnet name."
  type        = string
  default     = "tf-adv-elb10-subnet"
}

variable "subnet_cidr" {
  description = "Workload subnet CIDR."
  type        = string
  default     = "10.82.0.0/24"
}

variable "proxy_subnet_name" {
  description = "Proxy-only subnet name."
  type        = string
  default     = "tf-adv-elb10-proxy"
}

variable "proxy_subnet_cidr" {
  description = "Proxy-only subnet CIDR."
  type        = string
  default     = "10.132.0.0/23"
}

variable "machine_type" {
  description = "Backend VM machine type."
  type        = string
  default     = "e2-micro"
}

variable "affinity_cookie_ttl_sec" {
  description = "Cookie TTL in seconds for GENERATED_COOKIE and HTTP_COOKIE."
  type        = number
  default     = 3600
}

variable "iap_member" {
  description = "IAM member granted IAP tunnel and OS Login (for example, user:you@example.com)."
  type        = string

  validation {
    condition     = can(regex("^(user|serviceAccount|group):.+", var.iap_member))
    error_message = "iap_member must look like user:email, serviceAccount:email, or group:email."
  }
}
