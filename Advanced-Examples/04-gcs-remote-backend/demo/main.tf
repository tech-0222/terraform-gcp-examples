locals {
  demo_bucket_name = "${var.demo_bucket_prefix}-${var.project_id}"
}

# Tiny resource whose state is stored in the GCS backend created by the parent module.
# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket
resource "google_storage_bucket" "demo" {
  name                        = local.demo_bucket_name
  location                    = "ASIA-NORTHEAST1"
  force_destroy               = true
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  labels = {
    env        = "test"
    system     = "tf-examples"
    component  = "storage"
    managed_by = "terraform"
    example    = "04-gcs-remote-backend-demo"
  }
}
