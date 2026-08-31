# Artifact Registry: private Docker repository the cluster pulls from.
# Push is done by a developer/CI, not the cluster, so only read access is
# granted to the node Service Account.

# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/artifact_registry_repository
resource "google_artifact_registry_repository" "docker" {
  location      = var.region
  repository_id = var.artifact_registry_repository_id
  description   = "Docker images for ${var.cluster_name}"
  format        = "DOCKER"

  depends_on = [google_project_service.required]
}

# Image pulls are performed by kubelet using the node's own Service Account.
resource "google_artifact_registry_repository_iam_member" "gke_node_reader" {
  project    = google_artifact_registry_repository.docker.project
  location   = google_artifact_registry_repository.docker.location
  repository = google_artifact_registry_repository.docker.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.gke_node.email}"
}
