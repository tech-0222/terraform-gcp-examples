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
  default     = "tf-adv-gke-smcsi-vpc"
}

variable "gke_subnet_name" {
  description = "Subnet name for GKE nodes."
  type        = string
  default     = "tf-adv-gke-smcsi-subnet"
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
  default     = "tf-adv-gke-smcsi-mgmt-subnet"
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
  default     = "tf-adv-gke-smcsi"
}

variable "node_machine_type" {
  description = "Machine type for the GKE node pool. e2-small (2 vCPU) is not enough here: the Secret Manager CSI driver's DaemonSet plus GKE's own system Pods request ~99% of its allocatable CPU, leaving application Pods Pending with \"Insufficient cpu\". e2-medium is the smallest type observed to work."
  type        = string
  default     = "e2-medium"
}

variable "use_spot" {
  description = "Use Spot nodes to reduce cost."
  type        = bool
  default     = true
}

variable "bastion_instance_name" {
  description = "Bastion VM name."
  type        = string
  default     = "tf-adv-gke-smcsi-vm"
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

variable "secret_id" {
  description = "Secret Manager secret ID. Terraform creates the secret itself but never its value -- add versions with `gcloud secrets versions add` so no plaintext lands in tfstate."
  type        = string
  default     = "tf-adv-smcsi-demo"
}

variable "secret_id_second" {
  description = "Second Secret Manager secret ID, used by k8s/examples/01-multi-secret-one-volume.yaml to show multiple secrets in one volume."
  type        = string
  default     = "tf-adv-smcsi-demo-2"
}

variable "k8s_namespace" {
  description = "Kubernetes namespace of the ServiceAccount that mounts the secret. Must match k8s/01-serviceaccount.yaml -- it is part of the IAM principal string."
  type        = string
  default     = "default"
}

variable "k8s_service_account_name" {
  description = "Kubernetes ServiceAccount name granted access to the secret. Must match k8s/01-serviceaccount.yaml and the Pod's serviceAccountName."
  type        = string
  default     = "app-ksa"
}

variable "grant_ksa_secret_access" {
  description = "Grant the KSA roles/secretmanager.secretAccessor on the secret. Set to false and re-apply to watch the CSI mount fail -- that is how this example shows the binding is what makes the mount work."
  type        = bool
  default     = true
}
