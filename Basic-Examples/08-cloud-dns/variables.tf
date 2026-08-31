variable "project_id" {
  description = "Google Cloud Project ID."
  type        = string

  validation {
    condition     = length(trimspace(var.project_id)) > 0
    error_message = "project_id must not be empty."
  }
}

variable "region" {
  description = "Default region for the provider."
  type        = string
  default     = "asia-northeast1"
}

variable "network_name" {
  description = "Name of the VPC network used by the private DNS zone."
  type        = string
  default     = "tf-example-dns-vpc"
}

variable "managed_zone_name" {
  description = "Cloud DNS managed zone name."
  type        = string
  default     = "tf-example-private-zone"
}

variable "dns_name" {
  description = "DNS suffix for the private managed zone. Must end with a dot."
  type        = string
  default     = "example.internal."

  validation {
    condition     = endswith(var.dns_name, ".")
    error_message = "dns_name must end with a dot."
  }
}

variable "record_name" {
  description = "Relative name of the sample A record."
  type        = string
  default     = "app"
}

variable "record_ip" {
  description = "Private IPv4 address stored in the sample A record."
  type        = string
  default     = "10.10.0.10"
}

variable "record_ttl" {
  description = "TTL of the sample DNS record in seconds."
  type        = number
  default     = 300
}

variable "zone" {
  description = "Zone for the verification VMs."
  type        = string
  default     = "asia-northeast1-a"
}

variable "subnet_name" {
  description = "Subnet name for the VPC bound to the private zone."
  type        = string
  default     = "tf-example-dns-subnet"
}

variable "subnet_cidr" {
  description = "Subnet CIDR for the VPC bound to the private zone."
  type        = string
  default     = "10.30.0.0/24"
}

variable "external_network_name" {
  description = "Name of a separate VPC NOT bound to the private zone. Used to verify that resolution fails from outside the authorized network."
  type        = string
  default     = "tf-example-dns-external-vpc"
}

variable "external_subnet_name" {
  description = "Subnet name for the external VPC."
  type        = string
  default     = "tf-example-dns-external-subnet"
}

variable "external_subnet_cidr" {
  description = "Subnet CIDR for the external VPC."
  type        = string
  default     = "10.31.0.0/24"
}

variable "machine_type" {
  description = "Machine type for the verification VMs."
  type        = string
  default     = "e2-medium"
}

variable "vm_in_zone_name" {
  description = "Name of the VM inside the VPC bound to the private zone."
  type        = string
  default     = "tf-example-dns-vm-in-zone"
}

variable "vm_outside_zone_name" {
  description = "Name of the VM in the separate VPC, not bound to the private zone."
  type        = string
  default     = "tf-example-dns-vm-outside-zone"
}
