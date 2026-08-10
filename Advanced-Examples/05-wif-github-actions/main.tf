locals {
  demo_bucket_name = "${var.demo_bucket_prefix}-${var.project_id}"
}

data "google_project" "current" {
  project_id = var.project_id
}

# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_project_service
resource "google_project_service" "required" {
  for_each = toset([
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "sts.googleapis.com",
    "storage.googleapis.com",
  ])

  project = var.project_id
  service = each.value

  disable_on_destroy = false
}

# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/iam_workload_identity_pool
resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = var.pool_id
  display_name              = "GitHub Actions pool"
  description               = "Advanced-Examples/05-wif-github-actions"
  disabled                  = false

  depends_on = [google_project_service.required]
}

# GitHub Actions OIDC provider.
# Ref: https://cloud.google.com/iam/docs/workload-identity-federation-with-deployment-pipelines
# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/iam_workload_identity_pool_provider
resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = var.provider_id
  display_name                       = "GitHub OIDC"
  description                        = "token.actions.githubusercontent.com"
  disabled                           = false

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.actor"      = "assertion.actor"
    "attribute.repository" = "assertion.repository"
    "attribute.ref"        = "assertion.ref"
  }

  # Limit tokens to a single repository.
  attribute_condition = "assertion.repository == '${var.github_repository}'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_service_account
resource "google_service_account" "github" {
  account_id   = var.service_account_id
  display_name = "GitHub Actions (WIF)"
  description  = "Impersonated by GitHub Actions via Workload Identity Federation."

  depends_on = [google_project_service.required]
}

# Allow identities from the repository attribute to impersonate the SA.
# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_service_account_iam
resource "google_service_account_iam_member" "wif" {
  service_account_id = google_service_account.github.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_repository}"
}

# Tiny bucket so the workflow can prove access without broad project roles.
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
    component  = "wif"
    managed_by = "terraform"
    example    = "05-wif-github-actions"
  }

  depends_on = [google_project_service.required]
}

resource "google_storage_bucket_iam_member" "demo_viewer" {
  bucket = google_storage_bucket.demo.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.github.email}"
}

resource "google_storage_bucket_object" "hello" {
  name    = "hello-wif.txt"
  bucket  = google_storage_bucket.demo.name
  content = "hello-from-wif-demo\n"
}
