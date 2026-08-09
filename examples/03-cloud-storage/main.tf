locals {
  bucket_name = "${var.bucket_name_prefix}-${var.project_id}"
}

# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_project_service
resource "google_project_service" "storage" {
  project = var.project_id
  service = "storage.googleapis.com"

  disable_on_destroy = false
}

# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket
resource "google_storage_bucket" "example" {
  name                        = local.bucket_name
  location                    = var.location
  force_destroy               = var.force_destroy
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = false
  }

  labels = {
    env        = "test"
    system     = "tf-examples"
    component  = "storage"
    managed_by = "terraform"
    example    = "03-cloud-storage"
  }

  depends_on = [google_project_service.storage]
}
