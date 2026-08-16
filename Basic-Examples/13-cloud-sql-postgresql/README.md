# 13 - Cloud SQL for PostgreSQL

Cloud SQL for PostgreSQL の最小インスタンスと Database を Terraform で作成・確認・削除する基本サンプルです。

## 確認すること

- Cloud SQL Admin API を有効化できる
- PostgreSQL Instance を作成できる
- Instance 内に Database を作成できる
- `terraform destroy` で削除できる

## 作成されるGCPリソース

| リソース | 内容 |
|---|---|
| `google_project_service` | Cloud SQL Admin API |
| `google_sql_database_instance` | PostgreSQL Instance |
| `google_sql_database` | 検証用 Database |

## 基本構成

- PostgreSQL 15
- Cloud SQL Enterprise edition
- `db-f1-micro`
- Zonal
- SSD 10 GB
- Backup 無効
- Public IPv4 有効
- Authorized Network / DB User / Password は作成しない

Private IP やアプリ接続は `Advanced-Examples/` 側で扱う想定です。

## 前提条件

- ADC 認証済み
- 課金が有効な検証用 Project

## 必要なAPI

- `sqladmin.googleapis.com`

## 必要な権限（目安）

- Cloud SQL Admin 相当
- Service Usage を操作できる権限

## ファイル構成

```text
13-cloud-sql-postgresql/
├── README.md
├── docs/RESOURCE-PARAMETERS.md  # コンソール / API / Terraform の対応（手書き）
├── versions.tf
├── provider.tf
├── variables.tf
├── main.tf
├── outputs.tf
└── terraform.tfvars.example
```

リソースの明示設定と公式ドキュメント上の既定値の対応は `docs/RESOURCE-PARAMETERS.md` を参照してください。`PARAMETER.md` は terraform-docs の自動生成です。


`PARAMETER.md` / `DEPENDENCY-GRAPH.svg` / `.terraform.lock.hcl` は検証時に生成済みです。

## 設定方法

```bash
cd Basic-Examples/13-cloud-sql-postgresql
cp terraform.tfvars.example terraform.tfvars
```


## 使用方法

```bash
terraform init
terraform fmt -check
terraform validate
terraform plan
terraform apply
```

Cloud SQL Instance の作成には時間がかかる場合があります。

## 確認方法

```bash
gcloud sql instances describe "$(terraform output -raw instance_name)" \
  --project="$(terraform output -raw project_id)"

gcloud sql databases list \
  --instance="$(terraform output -raw instance_name)" \
  --project="$(terraform output -raw project_id)"
```

## 削除方法

```bash
terraform destroy
```

## 注意点 / 費用

- Cloud SQL Instance は起動中、継続して料金が発生します
- 検証時は作成後に必ず destroy してください
- 学習用のため `deletion_protection = false` としています。本番では有効化を推奨します
- Public IPv4 は有効ですが Authorized Network は設定しません
- DB User / Password はこの基本サンプルの対象外です

## 検証状況

実GCP環境（`YOUR_PROJECT_ID`）で `fmt / init / validate / plan / apply` を実施し、Instance が `RUNNABLE`（`POSTGRES_15` / `db-f1-micro`）であることと Database `appdb` を確認後、`terraform destroy` まで完了しています。
