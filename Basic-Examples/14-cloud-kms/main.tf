locals {
  key_ring_name = "${var.key_ring_name_prefix}-${var.project_id}"
}

# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_project_service
resource "google_project_service" "kms" {
  project = var.project_id
  service = "cloudkms.googleapis.com"

  disable_on_destroy = false
}

# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/kms_key_ring
resource "google_kms_key_ring" "example" {
  project  = var.project_id
  name     = local.key_ring_name
  location = var.location

  depends_on = [google_project_service.kms]
}

# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/kms_crypto_key
resource "google_kms_crypto_key" "example" {
  name     = var.crypto_key_name
  key_ring = google_kms_key_ring.example.id
  purpose  = "ENCRYPT_DECRYPT"
}
