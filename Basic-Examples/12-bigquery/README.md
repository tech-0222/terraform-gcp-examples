# 12 - BigQuery

BigQuery Dataset と Table を Terraform で作成・確認・削除する基本サンプルです。

## 確認すること

- BigQuery API / Cloud Resource Manager API を有効化できる
- Dataset を作成できる
- JSON Schema を持つ Table を作成できる
- `terraform destroy` で削除できる

## 作成されるGCPリソース

| リソース | 内容 |
|---|---|
| `google_project_service` | BigQuery / Cloud Resource Manager API |
| `google_bigquery_dataset` | 検証用 Dataset |
| `google_bigquery_table` | 検証用 Table |

## 前提条件

- Google Cloud CLI / Terraform がインストール済み
- ADC 認証済み
- 検証用 Project があること

## 必要なAPI

- `bigquery.googleapis.com`
- `cloudresourcemanager.googleapis.com`

## 必要な権限（目安）

- BigQuery Admin 相当
- Service Usage を操作できる権限

## ファイル構成

```text
12-bigquery/
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
cd Basic-Examples/12-bigquery
cp terraform.tfvars.example terraform.tfvars
```


```hcl
project_id = "your-project-id"
region     = "asia-northeast1"
location   = "asia-northeast1"
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
bq show --format=prettyjson "$(terraform output -raw dataset_reference)"
bq show --format=prettyjson "$(terraform output -raw table_reference)"
```

本サンプルではデータ行は投入しません。

## 削除方法

```bash
terraform destroy
```

## 注意点 / 費用

- Dataset / 空の Table だけであれば大きな費用は通常発生しません
- Query / Storage の利用量に応じて課金されます
- 学習用に `delete_contents_on_destroy = true`、Table の `deletion_protection = false` としています
- 本番用途では削除保護やデータ保持方針を見直してください

## 検証状況

実GCP環境（`tech-0222-tf-examples`）で `fmt / init / validate / plan / apply` を実施し、`bq show` で Dataset / Table を確認後、`terraform destroy` まで完了しています。
