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
  description = "Zone for the bastion VM. The GKE cluster is regional; see gke_zones for the node pool's zones."
  type        = string
  default     = "asia-northeast1-a"
}

variable "gke_zones" {
  description = "Zones the GKE node pool spans, one node each. Each zone gets its own NEG once app-a/b/c are deployed, so this needs 2+ zones to demonstrate multi-zone backends."
  type        = list(string)
  default     = ["asia-northeast1-a", "asia-northeast1-b", "asia-northeast1-c"]
}

variable "network_name" {
  description = "VPC network name."
  type        = string
  default     = "tf-adv-gke-ilbneg-vpc"
}

variable "gke_subnet_name" {
  description = "Subnet name for GKE nodes."
  type        = string
  default     = "tf-adv-gke-ilbneg-subnet"
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
  default     = "tf-adv-gke-ilbneg-mgmt-subnet"
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
  default     = "tf-adv-gke-ilbneg"
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
  default     = "tf-adv-gke-ilbneg-vm"
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

variable "artifact_registry_repository_id" {
  description = "Artifact Registry Docker repository ID."
  type        = string
  default     = "tf-adv-gke-ilbneg-repo"
}

variable "enable_ilb" {
  description = "Enable the Internal HTTP LB resources. Must stay false on the first apply: the backend services reference NEGs (neg-app-a/b/c) that only exist after `kubectl apply`-ing k8s/ilb-app-*.yaml on the already-created cluster. Set to true and re-apply once those NEGs exist."
  type        = bool
  default     = false
}

variable "ilb_proxy_subnet_cidr" {
  description = "CIDR for the proxy-only subnet required by INTERNAL_MANAGED load balancing. Must not overlap with any other subnet or the control plane CIDR."
  type        = string
  default     = "10.44.0.0/23"
}

variable "ilb_vip_address" {
  description = "Internal HTTP LB shared VIP, an address inside the GKE subnet. Chosen near the top of the range (not .1/.2) to avoid colliding with node internal IPs, which are already assigned by the time this address is reserved (nodes are created before enable_ilb=true)."
  type        = string
  default     = "10.40.0.250"
}
