variable "project_id" {
  description = "Google Cloud Project ID."
  type        = string

  validation {
    condition     = length(trimspace(var.project_id)) > 0
    error_message = "project_id must not be empty."
  }
}

variable "region" {
  description = "Region for the subnets and the Cloud KMS key ring. The key ring location must match the region the nodes run in."
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
  default     = "tf-adv-gke-cmek-vpc"
}

variable "gke_subnet_name" {
  description = "Subnet name for GKE nodes."
  type        = string
  default     = "tf-adv-gke-cmek-subnet"
}

variable "gke_subnet_cidr" {
  description = "Primary CIDR of the GKE subnet."
  type        = string
  default     = "10.40.0.0/24"
}

variable "pods_cidr" {
  description = "Secondary CIDR for Pods (VPC-native)."
  type        = string
  default     = "10.41.0.0/16"
}

variable "services_cidr" {
  description = "Secondary CIDR for Services (VPC-native)."
  type        = string
  default     = "10.42.0.0/20"
}

variable "bastion_subnet_name" {
  description = "Subnet name for the bastion VM. Kept separate from the GKE subnet so master_authorized_networks can allow only this range."
  type        = string
  default     = "tf-adv-gke-cmek-mgmt-subnet"
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
  default     = "tf-adv-gke-cmek"
}

variable "node_machine_type" {
  description = "Machine type for both node pools."
  type        = string
  default     = "e2-medium"
}

variable "node_count" {
  description = "Nodes per pool. One is enough to observe the key version on the boot disk."
  type        = number
  default     = 1
}

variable "use_spot" {
  description = "Use Spot nodes to reduce cost."
  type        = bool
  default     = true
}

variable "kms_key_ring_name" {
  description = "Cloud KMS key ring name. Key rings CANNOT be deleted in Google Cloud -- terraform destroy only drops it from state. Use a different name, or import the existing ring, when re-running this example."
  type        = string
  default     = "tf-adv-gke-cmek-ring"
}

variable "kms_crypto_key_name" {
  description = "Cloud KMS crypto key name. Like the key ring, it cannot be deleted -- only its versions can be destroyed."
  type        = string
  default     = "tf-adv-gke-cmek-boot-disk"
}

variable "keep_v1_node_pool" {
  description = "Keep the first node pool (created before the key rotation). Set to false and re-apply, after draining, to complete the migration to the new key version."
  type        = bool
  default     = true
}

variable "create_v2_node_pool" {
  description = "Create the second node pool. Set to true and re-apply AFTER rotating the key, so its boot disks use the new primary key version."
  type        = bool
  default     = false
}

variable "bastion_instance_name" {
  description = "Bastion VM name."
  type        = string
  default     = "tf-adv-gke-cmek-vm"
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
