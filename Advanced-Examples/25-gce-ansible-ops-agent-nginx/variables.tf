variable "project_id" {
  description = "Google Cloud Project ID."
  type        = string

  validation {
    condition     = length(trimspace(var.project_id)) > 0
    error_message = "project_id must not be empty."
  }
}

variable "region" {
  description = "Region for the subnet and the GCS bucket."
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
  default     = "tf-adv-gce-ans-vpc"
}

variable "subnet_name" {
  description = "Subnet name."
  type        = string
  default     = "tf-adv-gce-ans-subnet"
}

variable "subnet_cidr" {
  description = "CIDR of the subnet."
  type        = string
  default     = "10.50.0.0/24"
}

variable "bucket_prefix" {
  description = "Prefix for the Ansible asset bucket. The project ID is appended because bucket names are globally unique."
  type        = string
  default     = "tf-adv-gce-ansible"
}

variable "instance_name" {
  description = "VM name."
  type        = string
  default     = "tf-adv-gce-ans-web"
}

variable "machine_type" {
  description = "Machine type. e2-small is enough for nginx plus the Ops Agent; e2-micro runs out of memory during the agent install."
  type        = string
  default     = "e2-small"
}

variable "use_spot" {
  description = "Use a Spot VM to reduce cost. Spot instances can be reclaimed, which also makes the first-boot-only behaviour of the startup script easy to observe."
  type        = bool
  default     = true
}

variable "iap_member" {
  description = "IAM member granted IAP tunnel access (e.g. user:you@example.com). Must match your ADC / gcloud user for verification."
  type        = string

  validation {
    condition     = can(regex("^(user|serviceAccount|group):.+", var.iap_member))
    error_message = "iap_member must look like user:email, serviceAccount:email, or group:email."
  }
}
