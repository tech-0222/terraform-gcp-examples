variable "project_id" {
  description = "Google Cloud Project ID."
  type        = string

  validation {
    condition     = length(trimspace(var.project_id)) > 0
    error_message = "project_id must not be empty."
  }
}

variable "region" {
  description = "Region for the subnets."
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
  default     = "tf-adv-gke-dcc-vpc"
}

variable "gke_subnet_name" {
  description = "Subnet name for GKE nodes."
  type        = string
  default     = "tf-adv-gke-dcc-subnet"
}

variable "gke_subnet_cidr" {
  description = "Primary CIDR of the GKE subnet."
  type        = string
  default     = "10.40.0.0/24"
}

variable "pods_cidr" {
  description = "Secondary CIDR for Pods (VPC-native). Node auto-provisioning can add node pools, so leave room."
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
  default     = "tf-adv-gke-dcc-mgmt-subnet"
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
  default     = "tf-adv-gke-dcc"
}

variable "default_compute_class_enabled" {
  description = "cluster_autoscaling.default_compute_class_enabled. The REST API calls it clusterAutoscaling.defaultComputeClassConfig.enabled and the console calls it \"Autopilot compute class compatibility\". When on, the autoscaler uses the ComputeClass named `default` for workloads that do not select one. This is NOT enable_autopilot -- the cluster stays Standard."
  type        = bool
  default     = false
}

variable "enable_node_auto_provisioning" {
  description = "Turn on node auto-provisioning. Without it the autoscaler cannot create node pools, so the compute class has nothing to act on."
  type        = bool
  default     = true
}

variable "nap_max_cpu" {
  description = "Upper bound on vCPUs the autoscaler may provision across the cluster. Keep it small in a test project."
  type        = number
  default     = 12
}

variable "nap_max_memory_gb" {
  description = "Upper bound on memory (GB) the autoscaler may provision across the cluster."
  type        = number
  default     = 48
}

variable "node_machine_type" {
  description = "Machine type for the fixed node pool that carries system Pods."
  type        = string
  default     = "e2-medium"
}

variable "node_count" {
  description = "Nodes in the fixed pool. Anything that does not fit here is what triggers auto-provisioning."
  type        = number
  default     = 1
}

variable "use_spot" {
  description = "Use Spot nodes for the fixed pool to reduce cost."
  type        = bool
  default     = true
}

variable "bastion_instance_name" {
  description = "Bastion VM name."
  type        = string
  default     = "tf-adv-gke-dcc-vm"
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
