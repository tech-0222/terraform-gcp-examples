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
  description = "Zone for the backend VM."
  type        = string
  default     = "asia-northeast1-a"
}

variable "network_name" {
  description = "VPC network name."
  type        = string
  default     = "tf-adv-elb09-vpc"
}

variable "subnet_name" {
  description = "Workload subnet name."
  type        = string
  default     = "tf-adv-elb09-subnet"
}

variable "subnet_cidr" {
  description = "Workload subnet CIDR."
  type        = string
  default     = "10.81.0.0/24"
}

variable "proxy_subnet_name" {
  description = "Proxy-only subnet name."
  type        = string
  default     = "tf-adv-elb09-proxy"
}

variable "proxy_subnet_cidr" {
  description = "Proxy-only subnet CIDR."
  type        = string
  default     = "10.130.0.0/23"
}

variable "machine_type" {
  description = "Backend VM machine type."
  type        = string
  default     = "e2-micro"
}

variable "allowed_src_ips" {
  description = "Source IP CIDRs allowed by Cloud Armor (e.g. your public IP /32). All other clients get HTTP 403."
  type        = list(string)
}

variable "create_deny_client" {
  description = "If true, create a VM with an ephemeral external IP that is not allowlisted (expect 403 from that VM)."
  type        = bool
  default     = false
}
