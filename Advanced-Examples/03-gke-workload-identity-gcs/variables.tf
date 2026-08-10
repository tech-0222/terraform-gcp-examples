variable "project_id" {
  description = "Google Cloud Project ID."
  type        = string

  validation {
    condition     = length(trimspace(var.project_id)) > 0
    error_message = "project_id must not be empty."
  }
}

variable "region" {
  description = "Region for the subnet and GCS bucket."
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
  default     = "tf-adv-gke-wi"
}

variable "network_name" {
  description = "VPC network name."
  type        = string
  default     = "tf-adv-gke-wi-vpc"
}

variable "subnet_name" {
  description = "Subnet name."
  type        = string
  default     = "tf-adv-gke-wi-subnet"
}

variable "subnet_cidr" {
  description = "Primary subnet CIDR."
  type        = string
  default     = "10.50.0.0/24"
}

variable "pods_cidr" {
  description = "Secondary CIDR for Pods."
  type        = string
  default     = "10.51.0.0/16"
}

variable "services_cidr" {
  description = "Secondary CIDR for Services."
  type        = string
  default     = "10.52.0.0/20"
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

variable "bucket_name_prefix" {
  description = "Prefix for the GCS bucket (suffix is project_id)."
  type        = string
  default     = "tf-adv-gke-wi"
}

variable "k8s_namespace" {
  description = "Kubernetes namespace for the Workload Identity demo."
  type        = string
  default     = "wi-demo"
}

variable "k8s_service_account" {
  description = "Kubernetes ServiceAccount name bound to the GCP SA."
  type        = string
  default     = "gcs-writer"
}

variable "object_name" {
  description = "Object path written by the demo Job."
  type        = string
  default     = "workload-identity/hello.txt"
}
