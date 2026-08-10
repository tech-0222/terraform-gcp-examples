output "cluster_name" {
  description = "GKE cluster name."
  value       = google_container_cluster.primary.name
}

output "cluster_location" {
  description = "GKE cluster location (zone)."
  value       = google_container_cluster.primary.location
}

output "bucket_name" {
  description = "GCS bucket used by the Workload Identity demo."
  value       = google_storage_bucket.demo.name
}

output "object_name" {
  description = "Object written by the demo Job."
  value       = var.object_name
}

output "gcp_service_account_email" {
  description = "GCP SA impersonated by the Kubernetes SA."
  value       = google_service_account.gcs.email
}

output "k8s_namespace" {
  description = "Kubernetes namespace for the demo."
  value       = var.k8s_namespace
}

output "k8s_service_account" {
  description = "Kubernetes ServiceAccount bound via Workload Identity."
  value       = var.k8s_service_account
}

output "get_credentials_example" {
  description = "Example command to fetch kubeconfig."
  value       = "gcloud container clusters get-credentials ${google_container_cluster.primary.name} --zone=${google_container_cluster.primary.location} --project=${var.project_id}"
}

output "gsutil_cat_example" {
  description = "Read the object written by the Job."
  value       = "gsutil cat gs://${google_storage_bucket.demo.name}/${var.object_name}"
}
