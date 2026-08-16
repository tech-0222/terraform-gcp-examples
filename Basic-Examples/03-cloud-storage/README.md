# 03 - Cloud Storage

Cloud Storage Bucket を Terraform で作成・確認・削除するサンプルです。

## 確認すること

- Bucket を作成できる
- Uniform bucket-level access を有効にできる
- Public access prevention を enforced にできる
- `terraform destroy` で削除できる

## 作成されるGCPリソース

| リソース | 内容 |
|---|---|
| `google_project_service` | Cloud Storage API 有効化 |
| `google_storage_bucket` | 検証用 Bucket |

Bucket 名はデフォルトで `tf-example-<project_id>` です（グローバル一意）。

## 前提条件

- ADC 認証済み
- 検証用 Project があること

## 必要なAPI

- `storage.googleapis.com`

## 必要な権限（目安）

- Storage Admin 相当
- Service Usage Consumer

## ファイル構成

```text
03-cloud-storage/
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


## 設定方法

```bash
cd Basic-Examples/03-cloud-storage
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

```bash
gsutil ls -L -b "gs://$(terraform output -raw bucket_name)"
# or
gcloud storage buckets describe "gs://$(terraform output -raw bucket_name)"
```

## 削除方法

```bash
terraform destroy
```

デフォルトで `force_destroy = true` のため、Bucket 内にオブジェクトがあっても destroy できます。学習用以外では慎重に設定してください。

## 注意点 / 費用

- 空の Bucket 自体の料金はほぼ発生しません
- オブジェクト保存・通信には課金されます
- 本サンプルではオブジェクトは作成しません
- Public 公開は禁止（`public_access_prevention = enforced`）しています
