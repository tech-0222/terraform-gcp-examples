variable "project_id" {
  description = "Google Cloud Project ID."
  type        = string

  validation {
    condition     = length(trimspace(var.project_id)) > 0
    error_message = "project_id must not be empty."
  }
}

variable "region" {
  description = "Region for the subnets and the Cloud KMS key ring."
  type        = string
  default     = "asia-northeast1"
}

variable "zone" {
  description = "Zone for the zonal GKE cluster and the bastion VM."
  type        = string
  default     = "asia-northeast1-a"
}

variable "network_name" {
  description = "VPC network name."
  type        = string
  default     = "tf-adv-gke-bg-vpc"
}

variable "gke_subnet_name" {
  description = "Subnet name for GKE nodes."
  type        = string
  default     = "tf-adv-gke-bg-subnet"
}

variable "gke_subnet_cidr" {
  description = "Primary CIDR of the GKE subnet."
  type        = string
  default     = "10.40.0.0/24"
}

variable "pods_cidr" {
  description = "Secondary CIDR for Pods (VPC-native). Sized for the doubled node count during a BLUE_GREEN upgrade."
  type        = string
  default     = "10.41.0.0/16"
}

variable "services_cidr" {
  description = "Secondary CIDR for Services (VPC-native)."
  type        = string
  default     = "10.42.0.0/20"
}

variable "bastion_subnet_name" {
  description = "Subnet name for the bastion VM."
  type        = string
  default     = "tf-adv-gke-bg-mgmt-subnet"
}

variable "bastion_subnet_cidr" {
  description = "CIDR of the bastion subnet."
  type        = string
  default     = "10.43.0.0/24"
}

variable "master_ipv4_cidr_block" {
  description = "CIDR for the private cluster control plane. Must not overlap with any subnet."
  type        = string
  default     = "172.16.4.0/28"
}

variable "cluster_name" {
  description = "GKE cluster name."
  type        = string
  default     = "tf-adv-gke-bg"
}

variable "release_channel" {
  description = "GKE release channel. Both master_version and node_pool_version must be valid versions in this channel -- check with `gcloud container get-server-config`."
  type        = string
  default     = "REGULAR"
}

variable "master_version" {
  description = "Control plane version at creation. Must be NEWER than node_pool_version, otherwise there is nothing for the node pool to upgrade to. Versions age out of a channel, so check availability before applying."
  type        = string
  default     = "1.35.7-gke.1150000"
}

variable "node_pool_version" {
  description = "Node pool version at creation. Deliberately older than master_version. The upgrade to master_version is triggered with gcloud, not Terraform, so `version` is in lifecycle.ignore_changes."
  type        = string
  default     = "1.35.7-gke.1027000"
}

variable "node_machine_type" {
  description = "Machine type for the node pool."
  type        = string
  default     = "e2-medium"
}

variable "node_count" {
  description = "Nodes in the pool. Two is the minimum that shows batching, and a BLUE_GREEN upgrade briefly doubles this -- budget for 2x."
  type        = number
  default     = 2
}

variable "use_spot" {
  description = "Use Spot nodes to reduce cost."
  type        = bool
  default     = true
}

variable "node_pool_soak_duration" {
  description = "How long the blue node pool is kept after the workload has moved to green. This is the rollback window: once it expires blue is deleted and rollback is no longer possible. GKE's default is 3600s; this example uses a short value so the whole cycle finishes in one sitting."
  type        = string
  default     = "600s"
}

variable "blue_green_batch_percentage" {
  description = "Fraction (0-1, NOT a percent) of nodes moved from blue to green per batch. 0.5 with 2 nodes means one node at a time."
  type        = number
  default     = 0.5

  validation {
    condition     = var.blue_green_batch_percentage > 0 && var.blue_green_batch_percentage <= 1
    error_message = "blue_green_batch_percentage is a fraction between 0 and 1, not a percentage."
  }
}

variable "blue_green_batch_soak_duration" {
  description = "Pause between batches. Time to notice a problem before the next batch moves."
  type        = string
  default     = "60s"
}

variable "kms_key_ring_name" {
  description = "Cloud KMS key ring name. Key rings CANNOT be deleted in Google Cloud, and terraform destroy schedules the key versions for destruction -- use a fresh name when re-running this example."
  type        = string
  default     = "tf-adv-gke-bg-ring"
}

variable "kms_crypto_key_name" {
  description = "Cloud KMS crypto key name. Like the key ring, it cannot be deleted."
  type        = string
  default     = "tf-adv-gke-bg-boot-disk"
}

variable "bastion_instance_name" {
  description = "Bastion VM name."
  type        = string
  default     = "tf-adv-gke-bg-vm"
}

variable "bastion_machine_type" {
  description = "Machine type for the bastion VM."
  type        = string
  default     = "e2-medium"
}

variable "iap_member" {
  description = "IAM member granted IAP tunnel access to the bastion (e.g. user:you@example.com). Must match your ADC / gcloud user for verification."
  type        = string

  validation {
    condition     = can(regex("^(user|serviceAccount|group):.+", var.iap_member))
    error_message = "iap_member must look like user:email, serviceAccount:email, or group:email."
  }
}
