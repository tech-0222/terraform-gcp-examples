# 10 - Pub/Sub

Pub/Sub Topic と Pull Subscription を Terraform で作成し、メッセージの publish / pull を確認する最小サンプルです。

## 確認すること

- Pub/Sub API を有効化できる
- Topic を作成できる
- Pull Subscription を作成できる
- `gcloud` でメッセージを publish / pull できる
- `terraform destroy` で削除できる

## 作成されるGCPリソース

| リソース | 内容 |
|---|---|
| `google_project_service` | Pub/Sub API |
| `google_pubsub_topic` | 検証用 Topic |
| `google_pubsub_subscription` | Pull Subscription |

## 前提条件

- Google Cloud CLI / Terraform がインストール済み
- ADC 認証済み
- 検証用 Project があること

## 必要なAPI

- `pubsub.googleapis.com`

## 必要な権限（目安）

- Pub/Sub Admin 相当
- Service Usage Consumer

## ファイル構成

```text
10-pubsub/
├── README.md
├── versions.tf
├── provider.tf
├── variables.tf
├── main.tf
├── outputs.tf
└── terraform.tfvars.example
```

## 設定方法

```bash
cd Basic-Examples/10-pubsub
cp terraform.tfvars.example terraform.tfvars
```

```hcl
project_id = "your-project-id"
region     = "asia-northeast1"
```

## 使用方法

```bash
terraform init
terraform fmt -check
terraform validate
terraform plan
terraform apply
```

## 確認方法

Topic / Subscription:

```bash
gcloud pubsub topics describe "$(terraform output -raw topic_name)" \
  --project="$(grep project_id terraform.tfvars | cut -d'"' -f2)"

gcloud pubsub subscriptions describe "$(terraform output -raw subscription_name)" \
  --project="$(grep project_id terraform.tfvars | cut -d'"' -f2)"
```

テストメッセージ:

```bash
$(terraform output -raw publish_example)
$(terraform output -raw pull_example)
```

## 削除方法

```bash
terraform destroy
```

## 注意点 / 費用

- Pub/Sub はデータ量や配信量に応じて料金が発生する可能性があります
- 本サンプルは Push / BigQuery / Cloud Storage Subscription を扱いません
- 応用連携は `Advanced-Examples/` で扱います
