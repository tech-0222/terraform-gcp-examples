output "cluster_name" {
  value = google_container_cluster.primary.name
}

output "get_credentials" {
  value       = "gcloud container clusters get-credentials ${google_container_cluster.primary.name} --zone ${var.zone} --project ${var.project_id}"
  description = "kubectl の接続設定"
}

output "node_machine_type" {
  value = var.node_machine_type
}
