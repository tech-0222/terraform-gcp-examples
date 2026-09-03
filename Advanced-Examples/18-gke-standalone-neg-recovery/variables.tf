variable "project_id" {
  description = "Google Cloud Project ID."
  type        = string

  validation {
    condition     = length(trimspace(var.project_id)) > 0
    error_message = "project_id must not be empty."
  }
}

variable "region" {
  description = "Region for the subnets and Artifact Registry."
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
  default     = "tf-adv-gke-negrec-vpc"
}

variable "gke_subnet_name" {
  description = "Subnet name for GKE nodes."
  type        = string
  default     = "tf-adv-gke-negrec-subnet"
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

variable "max_pods_per_node" {
  description = "Maximum Pods per node (default_max_pods_per_node). null leaves it unset, which uses the GKE default (110). Immutable after cluster creation -- changing it requires recreating the node pool."
  type        = number
  default     = null
}

variable "services_cidr" {
  description = "Secondary CIDR for Services (VPC-native)."
  type        = string
  default     = "10.42.0.0/20"
}

variable "bastion_subnet_name" {
  description = "Subnet name for the bastion VM. Kept separate from the GKE subnet so master_authorized_networks can allow only this range."
  type        = string
  default     = "tf-adv-gke-negrec-mgmt-subnet"
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
  default     = "tf-adv-gke-negrec"
}

variable "node_machine_type" {
  description = "Machine type for the GKE node pool."
  type        = string
  default     = "e2-small"
}

variable "use_spot" {
  description = "Use Spot nodes to reduce cost."
  type        = bool
  default     = true
}

variable "bastion_instance_name" {
  description = "Bastion VM name."
  type        = string
  default     = "tf-adv-gke-negrec-vm"
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

variable "gke_zones" {
  description = "Zones the regional GKE node pool spans, one node each. GKE creates one standalone NEG per zone, so 2+ zones make the multi-backend case realistic."
  type        = list(string)
  default     = ["asia-northeast1-a", "asia-northeast1-b"]
}

variable "neg_name" {
  description = "Name of the standalone NEG. Must match the name in the Service's cloud.google.com/neg annotation (k8s/neg-app.yaml) -- Terraform reads the NEG by this name, it does not create it."
  type        = string
  default     = "tf-adv-negrec-neg"
}

variable "app_port" {
  description = "Port the demo Pods serve on, and the port the NEG exposes. Also opened to Google's health-check ranges in network.tf."
  type        = number
  default     = 80
}

variable "enable_lb" {
  description = "Enable the external Application Load Balancer. Must stay false on the first apply: the backend service reads NEGs that only exist after `kubectl apply`-ing k8s/neg-app.yaml on the running cluster."
  type        = bool
  default     = false
}
