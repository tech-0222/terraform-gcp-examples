# gcloud で作るときと同じ JSON ファイルを渡す。
# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/monitoring_dashboard
resource "google_monitoring_dashboard" "web" {
  dashboard_json = file("${path.module}/dashboards/web-service-overview.json")

  depends_on = [google_project_service.required]
}
