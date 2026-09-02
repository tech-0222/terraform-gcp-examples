variable "project_id" {
  description = "Project A: Google Cloud Project ID hosting the GKE cluster and bastion."
  type        = string

  validation {
    condition     = length(trimspace(var.project_id)) > 0
    error_message = "project_id must not be empty."
  }
}

variable "target_project_id" {
  description = "Project B: Google Cloud Project ID hosting the destination VM. Must be a different project than project_id for the cross-project VPC Peering to be meaningful."
  type        = string

  validation {
    condition     = length(trimspace(var.target_project_id)) > 0
    error_message = "target_project_id must not be empty."
  }
}

variable "region" {
  description = "Region for both projects' subnets."
  type        = string
  default     = "asia-northeast1"
}

variable "zone" {
  description = "Zone for the zonal GKE cluster, the bastion VM, and the target VM."
  type        = string
  default     = "asia-northeast1-a"
}

# --- Project A: network ---

variable "network_a_name" {
  description = "Project A VPC network name."
  type        = string
  default     = "tf-adv-gke-ipmasq-a-vpc"
}

variable "gke_subnet_cidr" {
  description = "Primary CIDR of the GKE node subnet in Project A."
  type        = string
  default     = "10.10.0.0/28"
}

variable "bastion_subnet_cidr" {
  description = "CIDR of the bastion subnet in Project A."
  type        = string
  default     = "10.10.1.0/28"
}

variable "pod_cidr" {
  description = "Pod CIDR for the routes-based cluster. This is a VPC custom route once the cluster exists, not a subnet secondary range -- that's the entire point of this example."
  type        = string
  default     = "172.16.0.0/16"
}

variable "services_cidr" {
  description = "Service CIDR for the routes-based cluster."
  type        = string
  default     = "172.17.0.0/20"
}

variable "master_ipv4_cidr_block" {
  description = "CIDR for the private cluster control plane. Must not overlap with any subnet or with pod_cidr/services_cidr."
  type        = string
  default     = "192.168.255.0/28"
}

# --- Project B: network ---

variable "network_b_name" {
  description = "Project B VPC network name."
  type        = string
  default     = "tf-adv-gke-ipmasq-b-vpc"
}

variable "target_subnet_cidr" {
  description = "CIDR of the destination VM's subnet in Project B."
  type        = string
  default     = "10.20.0.0/24"
}

variable "target_vm_ip" {
  description = "Static internal IP for the destination VM, inside target_subnet_cidr."
  type        = string
  default     = "10.20.0.10"
}

# --- Peering switch (the core variable this example is about) ---

variable "peering_custom_routes" {
  description = "Whether the VPC Peering exports/imports custom routes. false (the default) means Project B never learns a route to pod_cidr, so Pod-IP-sourced traffic to the target VM cannot get a return path -- this is the failure this example reproduces and then works around with ip-masq-agent, without ever setting this to true."
  type        = bool
  default     = false
}

# --- GKE ---

variable "cluster_name" {
  description = "GKE cluster name."
  type        = string
  default     = "tf-adv-gke-ipmasq"
}

variable "node_machine_type" {
  description = "Machine type for the GKE node pool. e2-small (2GB) is not enough -- the Konnectivity Agent's memory request leaves it Pending. e2-standard-2 (8GB) is the smallest machine type observed to work reliably."
  type        = string
  default     = "e2-standard-2"
}

variable "use_spot" {
  description = "Use Spot for the GKE node and the target VM to reduce cost."
  type        = bool
  default     = true
}

# --- Bastion (Project A) ---

variable "bastion_instance_name" {
  description = "Bastion VM name."
  type        = string
  default     = "tf-adv-gke-ipmasq-bastion"
}

variable "bastion_machine_type" {
  description = "Machine type for the bastion VM."
  type        = string
  default     = "e2-medium"
}

variable "iap_member" {
  description = "IAM member granted IAP tunnel access to the bastion and the target VM (e.g. user:you@example.com). Must match your ADC / gcloud user for verification. Granted in both projects."
  type        = string

  validation {
    condition     = can(regex("^(user|serviceAccount|group):.+", var.iap_member))
    error_message = "iap_member must look like user:email, serviceAccount:email, or group:email."
  }
}

# --- Target VM (Project B) ---

variable "target_vm_name" {
  description = "Destination VM name in Project B."
  type        = string
  default     = "tf-adv-gke-ipmasq-target-vm"
}

variable "target_vm_machine_type" {
  description = "Machine type for the destination VM."
  type        = string
  default     = "e2-medium"
}
