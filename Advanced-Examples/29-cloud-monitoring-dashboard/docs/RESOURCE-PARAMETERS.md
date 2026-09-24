# リソースのパラメータ対応

コンソール / API の項目と、Terraform の属性の対応。

## Monitoring: ダッシュボード

`google_monitoring_dashboard` は `dashboard_json` に Dashboards API の JSON をそのまま渡す。個々の項目は Terraform の属性ではなく、JSON のフィールドになる。

| コンソール | JSON（`dashboard_json`） | このサンプルの値 |
|---|---|---|
| ダッシュボード名 | `displayName` | `Web Service Overview` |
| ラベル | `labels` | `example = 29-cloud-monitoring-dashboard` |
| フィルタ（pinned） | `dashboardFilters[]`（`templateVariable` なし） | `USER_METADATA_LABEL` `environment = test` |
| 変数（`$` で始まる） | `dashboardFilters[]`（`templateVariable` あり） | `$cluster`（`cluster_name`）、`$namespace`（`namespace_name`） |
| アノテーション | `annotations.eventAnnotations[]` | `CLOUD_ALERTING_ALERT`、`CLOUD_RUN_DEPLOYMENT`、`GKE_WORKLOAD_DEPLOYMENT`、`GKE_POD_CRASH` |
| レイアウト | `mosaicLayout`（`columns`、`tiles[]`） | 48列 |
| ウィジェットの位置 | `tiles[].xPos` / `yPos` / `width` / `height` | **0 の座標は書かない**（google 7.46.1 で恒常差分になった） |
| スコアカードのしきい値 | `scorecard.thresholds[]` | `direction = ABOVE`、`color = RED`。`value` は省略（0 を超えたら赤） |

未指定の項目と API の挙動（実測）。

| 項目 | 挙動 |
|---|---|
| `xPos` / `yPos` が 0 | API は省いて返す。書いたままだと plan に `+ xPos = 0` が出続ける |
| xyChart の `targetAxis` | API が `Y1` を補う。provider が差分を抑制するので書かなくてよい |
| `etag` | API が払い出す。Terraform の設定には書かない |
| スコアカードの `thresholds[].value` が 0 | API は省いて返す。書いたままだと plan に `+ value = 0` が出続ける。キーごと省く |

Ref: [REST Resource: projects.dashboards](https://cloud.google.com/monitoring/api/ref_v3/rest/v1/projects.dashboards)、[google_monitoring_dashboard](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/monitoring_dashboard)

## Monitoring: アラートポリシー

| コンソール | Terraform | このサンプルの値 |
|---|---|---|
| 条件のフィルタ | `conditions.condition_threshold.filter` | Cloud Run の `request_count`、`response_code_class = 5xx` |
| 集計 | `aggregations` | `ALIGN_DELTA` 60s、`REDUCE_SUM`、`service_name` ごと |
| しきい値 | `threshold_value` / `comparison` | `> 0` |
| 継続時間 | `duration` | `0s` |
| 自動クローズ | `alert_strategy.auto_close` | `1800s` |
| 通知チャネル | `notification_channels` | 未指定（Incident が開くことだけを見る） |

## GKE

| コンソール | Terraform | このサンプルの値 |
|---|---|---|
| ロケーション | `location` | `asia-northeast1-a`（ゾーン） |
| リリースチャネル | `release_channel.channel` | `REGULAR` |
| ログ | `logging_config.enable_components` | `SYSTEM_COMPONENTS`、`WORKLOADS` |
| 監視 | `monitoring_config.enable_components` | `SYSTEM_COMPONENTS` |
| ラベル | `resource_labels` | `environment` など。**コンテナのメトリクスのユーザーラベルには入らない**（実測） |
| ノード | `node_config.machine_type` / `spot` | `e2-medium`、Spot |

## GCE

| コンソール | Terraform | このサンプルの値 |
|---|---|---|
| マシンタイプ | `machine_type` | `e2-small` |
| プロビジョニング | `scheduling.provisioning_model` | `SPOT` |
| 外部 IP | `network_interface.access_config` | 未指定（外部 IP なし、NAT 経由） |
| ラベル | `labels` | `environment` など。メトリクスの `metadata.user_labels` で絞れる（実測） |

## Cloud Run

| コンソール | Terraform | このサンプルの値 |
|---|---|---|
| コンテナイメージ | `template.containers.image` | `docker.io/mccutchen/go-httpbin:2.25.0` |
| 最大インスタンス数 | `template.scaling.max_instance_count` | 2 |
| 認証 | `google_cloud_run_v2_service_iam_member` | `allUsers` に `roles/run.invoker`（検証用） |
| ラベル | `labels` | `environment` など。**リビジョンのメトリクスのユーザーラベルでは一致しなかった**（実測） |
