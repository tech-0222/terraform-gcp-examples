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

variable "location" {
  description = "Cloud KMS location."
  type        = string
  default     = "global"
}

variable "key_ring_name_prefix" {
  description = "Prefix for the KeyRing name. Project ID is appended to reduce collisions."
  type        = string
  default     = "tf-example-keyring"
}

variable "crypto_key_name" {
  description = "CryptoKey name."
  type        = string
  default     = "tf-example-key"
}
