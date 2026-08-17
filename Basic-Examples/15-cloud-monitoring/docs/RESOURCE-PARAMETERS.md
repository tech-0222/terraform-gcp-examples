# 15 - リソースパラメータ対応

このファイルは **本サンプルの Cloud Monitoring Alert Policy** について対応づけます。自動生成の `docs/PARAMETER.md` とは別物です。GCE VM は作りません。メトリクス条件だけです。

一次情報:

- [google_monitoring_alert_policy](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/monitoring_alert_policy)
- [google_monitoring_notification_channel](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/monitoring_notification_channel)
- [AlertPolicy](https://cloud.google.com/monitoring/api/ref_v3/rest/v3/projects.alertPolicies)
- [CPU utilization metric](https://cloud.google.com/monitoring/api/metrics_gcp#gcp-compute)

## 確認コマンド

```bash
gcloud alpha monitoring policies list --format=json
```

（`gcloud monitoring` のサブコマンドは環境によって `alpha` が必要なことがあります。コンソールの Monitoring > Alerting でも確認できます。）

## google_monitoring_alert_policy.cpu_usage

| 項目 | 本サンプル | Terraform | API |
|---|---|---|---|
| 表示名 | `tf-example-gce-cpu-high` | `display_name` | `displayName` |
| combiner | `OR` | `combiner`。複数条件の結合。`AND` / `OR` / `AND_WITH_MATCHING_RESOURCE` | `combiner` |
| 有効 | オン | `enabled = true` | |
| フィルタ | GCE CPU utilization | `condition_threshold.filter` | `compute.googleapis.com/instance/cpu/utilization` |
| 比較 | より大きい | `COMPARISON_GT` | |
| しきい値 | `0.8`（80%） | `threshold_value`。0–1 の比率 | |
| 継続時間 | `300s` | `duration` | |
| アライン | `ALIGN_MEAN` / `300s` | `aggregations` | |
| トリガ | 1 時系列 | `trigger.count = 1` | |
| 通知先 | email チャネルがあれば設定 | `notification_channels` | 未設定ならポリシーのみ |

## google_monitoring_notification_channel.email

`notification_email` が `null`（既定）のときは **チャネルを作りません**（`count = 0`）。メールを入れると `type = "email"` で `labels.email_address` を設定します。

| 項目 | 本サンプル | Terraform |
|---|---|---|
| type | `email` | `type` |
| enabled | `true` | `enabled` |

VM が無いと CPU 時系列は出ません。条件定義の確認用です。
