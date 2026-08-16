# 15 - Cloud Monitoring

Cloud Monitoring の Alert Policy と、任意の Email Notification Channel を Terraform で作成する基本サンプルです。

実際の Compute Engine VM は作成せず、`gce_instance` の CPU utilization メトリクスを対象とする Alert Policy だけを作成します。

## 確認すること

- Cloud Monitoring API / Compute Engine API を有効化できる
- GCE CPU utilization を対象とする Alert Policy を作成できる
- 任意で Email Notification Channel を作成できる
- `terraform destroy` で削除できる

## 作成されるGCPリソース

| リソース | 内容 |
|---|---|
| `google_project_service` | Monitoring / Compute Engine API |
| `google_monitoring_alert_policy` | GCE CPU utilization Alert Policy |
| `google_monitoring_notification_channel` | Email Channel（`notification_email` 指定時のみ） |

## 前提条件

- ADC 認証済み
- 検証用 Project

## 必要なAPI

- `monitoring.googleapis.com`
- `compute.googleapis.com`

## 必要な権限（目安）

- Monitoring Editor 相当
- Email Channel を作る場合は Notification Channel Editor 相当
- Service Usage を操作できる権限

## ファイル構成

```text
15-cloud-monitoring/
├── README.md
├── RESOURCE-PARAMETERS.md  # コンソール / API / Terraform の対応（手書き）
├── versions.tf
├── provider.tf
├── variables.tf
├── main.tf
├── outputs.tf
└── terraform.tfvars.example
```

リソースの明示設定と公式ドキュメント上の既定値の対応は `RESOURCE-PARAMETERS.md` を参照してください。`PARAMETER.md` は terraform-docs の自動生成です。


`PARAMETER.md` / `DEPENDENCY-GRAPH.svg` / `.terraform.lock.hcl` は検証時に生成済みです。

## 設定方法

```bash
cd Basic-Examples/15-cloud-monitoring
cp terraform.tfvars.example terraform.tfvars
```


Alert Policy のみ作る場合、`notification_email` は設定不要です。

Email Notification Channel も作る場合:

```hcl
notification_email        = "you@example.com"
notification_channel_name = "tf-example-email"
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

```bash
gcloud monitoring policies list \
  --project="$(terraform output -raw project_id)"
```

本サンプルは VM を作成しないため、Alert Policy を作成しても対象 VM が存在しなければ通常は発火しません。

## 削除方法

```bash
terraform destroy
```

## 注意点 / 費用

- Alert Policy / Notification Channel の設定だけを対象にします
- GCE VM はこのサンプルでは作成しません
- Email Channel は `notification_email` を指定した場合のみ作成します
- 実際に通知させる検証は、既存VMまたは別サンプルとの組み合わせで行います

## 検証状況

実GCP環境（`YOUR_PROJECT_ID`）で `fmt / init / validate / plan / apply` を実施し、Alert Policy / Email Notification Channel の作成を確認後、`terraform destroy` まで完了しています。
