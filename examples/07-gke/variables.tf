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
  description = "Zone for the zonal GKE cluster."
  type        = string
  default     = "asia-northeast1-a"
}

variable "cluster_name" {
  description = "GKE cluster name."
  type        = string
  default     = "tf-example-gke"
}

variable "network_name" {
  description = "VPC network name."
  type        = string
  default     = "tf-example-gke-vpc"
}

variable "subnet_name" {
  description = "Subnet name."
  type        = string
  default     = "tf-example-gke-subnet"
}

variable "subnet_cidr" {
  description = "Primary subnet CIDR."
  type        = string
  default     = "10.40.0.0/24"
}

variable "pods_cidr" {
  description = "Secondary CIDR for Pods."
  type        = string
  default     = "10.41.0.0/16"
}

variable "services_cidr" {
  description = "Secondary CIDR for Services."
  type        = string
  default     = "10.42.0.0/20"
}

variable "machine_type" {
  description = "Node machine type."
  type        = string
  default     = "e2-medium"
}

variable "node_count" {
  description = "Number of nodes in the Spot node pool."
  type        = number
  default     = 1
}
