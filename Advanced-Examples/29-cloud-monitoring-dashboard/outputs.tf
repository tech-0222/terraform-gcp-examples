output "dashboard_id" {
  value       = google_monitoring_dashboard.web.id
  description = "Terraform で作ったダッシュボードのリソース名"
}

output "run_url" {
  value = google_cloud_run_v2_service.api.uri
}

output "get_credentials" {
  value       = "gcloud container clusters get-credentials ${google_container_cluster.primary.name} --zone ${var.zone} --project ${var.project_id}"
  description = "kubectl の接続設定"
}
