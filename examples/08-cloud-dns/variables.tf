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
