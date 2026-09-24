# ダッシュボードの Incident 一覧とイベント注釈に載せるインシデントの発生源。
# 通知チャネルは付けない（Incident が開くことだけを見る）。
# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/monitoring_alert_policy
resource "google_monitoring_alert_policy" "run_5xx" {
  display_name = "${var.run_service_name} 5xx"
  combiner     = "OR"
  user_labels  = local.common_labels

  conditions {
    display_name = "Cloud Run 5xx > 0"

    condition_threshold {
      filter          = "resource.type = \"cloud_run_revision\" AND resource.labels.service_name = \"${var.run_service_name}\" AND metric.type = \"run.googleapis.com/request_count\" AND metric.labels.response_code_class = \"5xx\""
      comparison      = "COMPARISON_GT"
      threshold_value = 0
      duration        = "0s"

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_DELTA"
        cross_series_reducer = "REDUCE_SUM"
        group_by_fields      = ["resource.labels.service_name"]
      }

      trigger {
        count = 1
      }
    }
  }

  alert_strategy {
    auto_close = "1800s"
  }

  depends_on = [google_project_service.required]
}
