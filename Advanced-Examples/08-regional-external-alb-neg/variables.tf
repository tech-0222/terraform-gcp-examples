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

variable "zone_a" {
  description = "Zone for backend-a / backend-a2."
  type        = string
  default     = "asia-northeast1-a"
}

variable "zone_c" {
  description = "Zone for backend-b."
  type        = string
  default     = "asia-northeast1-c"
}

variable "network_name" {
  description = "VPC network name."
  type        = string
  default     = "tf-adv-elb08-vpc"
}

variable "subnet_name" {
  description = "Workload subnet name."
  type        = string
  default     = "tf-adv-elb08-subnet"
}

variable "subnet_cidr" {
  description = "Workload subnet CIDR."
  type        = string
  default     = "10.80.0.0/24"
}

variable "proxy_subnet_name" {
  description = "Proxy-only subnet name (required for regional Envoy ALB)."
  type        = string
  default     = "tf-adv-elb08-proxy"
}

variable "proxy_subnet_cidr" {
  description = "Proxy-only subnet CIDR. Regional managed proxy typically needs at least /23."
  type        = string
  default     = "10.128.0.0/23"
}

variable "machine_type" {
  description = "Backend VM machine type. e2-micro is enough for a static HTTP identity."
  type        = string
  default     = "e2-micro"
}

variable "iap_member" {
  description = "IAM member granted IAP tunnel and OS Login (for example, user:you@example.com)."
  type        = string

  validation {
    condition     = can(regex("^(user|serviceAccount|group):.+", var.iap_member))
    error_message = "iap_member must look like user:email, serviceAccount:email, or group:email."
  }
}
