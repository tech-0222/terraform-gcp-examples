# Secret Manager: the container only. The value itself is deliberately NOT
# managed by Terraform.
#
# google_secret_manager_secret_version's secret_data would put the plaintext
# into terraform.tfstate, so this example creates only the secret resource
# and leaves the value to `gcloud secrets versions add` (see README). That
# also means `terraform destroy` removes the secret and every version with
# it -- nothing survives in state.

data "google_project" "current" {
  project_id = var.project_id
}

resource "google_project_service" "secretmanager" {
  project = var.project_id
  service = "secretmanager.googleapis.com"

  disable_on_destroy = false
}

resource "google_secret_manager_secret" "demo" {
  secret_id = var.secret_id

  replication {
    auto {}
  }

  labels = {
    env        = "test"
    system     = "tf-examples"
    managed_by = "terraform"
    example    = "19-gke-secret-manager-csi"
  }

  depends_on = [google_project_service.secretmanager]
}

locals {
  # Workload Identity Federation for GKE lets a Kubernetes ServiceAccount be
  # named directly as an IAM principal. No Google Service Account is created,
  # no iam.gke.io/gcp-service-account annotation, no key JSON.
  # Ref: https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity
  ksa_principal = "principal://iam.googleapis.com/projects/${data.google_project.current.number}/locations/global/workloadIdentityPools/${var.project_id}.svc.id.goog/subject/ns/${var.k8s_namespace}/sa/${var.k8s_service_account_name}"
}

# Grants the KSA read access to this one secret. Removing this binding is
# what makes the CSI mount fail, which the README uses to prove the
# permission is actually load-bearing rather than incidental.
resource "google_secret_manager_secret_iam_member" "ksa_accessor" {
  count = var.grant_ksa_secret_access ? 1 : 0

  project   = google_secret_manager_secret.demo.project
  secret_id = google_secret_manager_secret.demo.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = local.ksa_principal
}

# A second secret, used only by k8s/examples/01-multi-secret-one-volume.yaml
# to show several secrets landing in one volume as separate files.
resource "google_secret_manager_secret" "demo_second" {
  secret_id = var.secret_id_second

  replication {
    auto {}
  }

  labels = {
    env        = "test"
    system     = "tf-examples"
    managed_by = "terraform"
    example    = "19-gke-secret-manager-csi"
  }

  depends_on = [google_project_service.secretmanager]
}

resource "google_secret_manager_secret_iam_member" "ksa_accessor_second" {
  count = var.grant_ksa_secret_access ? 1 : 0

  project   = google_secret_manager_secret.demo_second.project
  secret_id = google_secret_manager_secret.demo_second.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = local.ksa_principal
}
