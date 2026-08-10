terraform {
  required_version = ">= 1.10.0, < 2.0.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
  }

  # Values come from backend.hcl (do not commit real bucket names if policy forbids).
  # Ref: https://developer.hashicorp.com/terraform/language/backend/gcs
  backend "gcs" {}
}
