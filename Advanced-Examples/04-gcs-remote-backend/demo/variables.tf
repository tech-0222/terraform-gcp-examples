variable "project_id" {
  description = "Google Cloud Project ID."
  type        = string
}

variable "region" {
  description = "Provider region."
  type        = string
  default     = "asia-northeast1"
}

variable "demo_bucket_prefix" {
  description = "Prefix for a tiny demo bucket managed with remote state."
  type        = string
  default     = "tf-adv-remote-demo"
}
