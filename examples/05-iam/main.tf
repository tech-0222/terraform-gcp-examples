# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_project_service
resource "google_project_service" "iam" {
  project = var.project_id
  service = "iam.googleapis.com"

  disable_on_destroy = false
}

# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_service_account
resource "google_service_account" "example" {
  account_id   = var.service_account_id
  display_name = var.service_account_display_name
  description  = "Sample service account for terraform-gcp-examples/05-iam."

  depends_on = [google_project_service.iam]
}

# Prefer google_project_iam_member (additive) over authoritativemember bindings.
# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_project_iam
resource "google_project_iam_member" "example" {
  project = var.project_id
  role    = var.project_iam_role
  member  = "serviceAccount:${google_service_account.example.email}"
}
