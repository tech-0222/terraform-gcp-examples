# 01 - Project Service（API有効化）

`google_project_service` を使い、指定した Google Cloud API を有効化するサンプルです。

## 確認すること

- Terraform から API を有効化できる
- 有効化後に `gcloud services list` で確認できる
- `terraform destroy` 時の挙動（API を無効化するか残すか）を理解できる

## 作成されるGCPリソース

| リソース | 内容 |
|---|---|
| `google_project_service` | 指定した API の有効化設定 |

デフォルトで有効化する API:

- `compute.googleapis.com`
- `iam.googleapis.com`
- `storage.googleapis.com`

## 前提条件

- Google Cloud CLI / Terraform がインストール済み
- 検証用 Google Cloud Project が存在する
- ADC で認証済み（`gcloud auth application-default login`）
- 対象 Project で Service Usage を操作できる権限がある（例: Owner / Editor、または `serviceusage.services.enable`）

## 必要なAPI

- `serviceusage.googleapis.com`（API 有効化の管理に必要。通常は Project 作成時に有効）

## 必要な権限（目安）

- `serviceusage.services.enable`
- `serviceusage.services.get`
- `serviceusage.services.list`

## ファイル構成

```text
01-project-service/
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
cd Basic-Examples/01-project-service

cp terraform.tfvars.example terraform.tfvars
```

`terraform.tfvars` 例:

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

```bash
gcloud services list --enabled --project="$(terraform output -raw project_id)" \
  --filter='config.name:(compute.googleapis.com OR iam.googleapis.com OR storage.googleapis.com)'
```

Terraform Output:

```text
enabled_services = [
  "compute.googleapis.com",
  "iam.googleapis.com",
  "storage.googleapis.com",
]
```

## 削除方法

```bash
terraform destroy
```

### destroy 時の注意（重要）

| `disable_on_destroy` | destroy 後の API |
|---|---|
| `false`（デフォルト） | **有効のまま残る**（State から管理対象外になるだけ） |
| `true` | API を無効化する |

学習・検証以外で既存 Project を使う場合は、デフォルトの `false` を推奨します。  
依存サービスまで無効化する場合は `disable_dependent_services = true` も検討しますが、影響範囲が大きいため慎重に使ってください。

## 注意点 / 費用

- API の有効化自体に追加料金は通常かかりません
- 有効化した API を使ってリソースを作ると課金対象になります
- 本サンプルは API 有効化のみで、Compute / Storage などの実体リソースは作成しません
