# 10 - リソースパラメータ対応

このファイルは **本サンプルの Pub/Sub Topic / Pull Subscription** について対応づけます。自動生成の `docs/PARAMETER.md` とは別物です。

一次情報:

- [google_pubsub_topic](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/pubsub_topic)
- [google_pubsub_subscription](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/pubsub_subscription)
- [Subscription properties](https://cloud.google.com/pubsub/docs/subscription-properties)
- [projects.subscriptions](https://cloud.google.com/pubsub/docs/reference/rest/v1/projects.subscriptions)

## 確認コマンド

```bash
gcloud pubsub topics describe tf-example-topic --format=json
gcloud pubsub subscriptions describe tf-example-subscription --format=json
```

## google_pubsub_topic.example

| 項目 | 本サンプル | Terraform | API |
|---|---|---|---|
| 名前 | `tf-example-topic` | `name` | `name` |
| メッセージ保持 | 未指定 | `message_retention_duration` | 既定は Topic 側の保持設定 |
| CMEK | 使わない | `kms_key_name` | |

## google_pubsub_subscription.example

| 項目 | 本サンプル | 区分 | Terraform | API / 公式 |
|---|---|---|---|---|
| 名前 | `tf-example-subscription` | 明示 | `name` | |
| 配信 | Pull（push_config なし） | 明示 | `push_config` 未設定 | |
| ack deadline | `20` 秒 | 明示 | `ack_deadline_seconds`。範囲 10–600。未指定 / 0 なら **10 秒**（[GCP](https://cloud.google.com/pubsub/docs/subscription-properties) / [Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/pubsub_subscription)） | `ackDeadlineSeconds` |
| メッセージ保持 | 未指定 | 未指定 | `message_retention_duration` | 既定 7 日 |
| exactly-once | 未指定 | 未指定 | `enable_exactly_once_delivery` | |

Push / BigQuery / Cloud Storage サブスクリプションは作りません。
