# 09 - Secret Manager

Secret Manager の Secret と Secret Version を Terraform で作成・確認・削除するサンプルです。

Terraform 1.11 以降の write-only argument を利用し、Secret 値を Terraform の plan / state に保存しない構成にします。

## 確認すること

- Secret Manager API を有効化できる
- Secret を作成できる
- write-only argument で Secret Version を作成できる
- `gcloud secrets versions access` で値を確認できる
- `terraform destroy` で削除できる

## 作成されるGCPリソース

| リソース | 内容 |
|---|---|
| `google_project_service` | Secret Manager API |
| `google_secret_manager_secret` | 検証用 Secret |
| `google_secret_manager_secret_version` | 検証用 Secret Version |

## 前提条件

- **Terraform 1.11 以上**
- Google Cloud CLI
- ADC 認証済み
- 検証用 Project があること

## 必要なAPI

- `secretmanager.googleapis.com`

## 必要な権限（目安）

- Secret Manager Admin 相当
- Service Usage Consumer

## ファイル構成

```text
09-secret-manager/
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


## 設定方法

```bash
cd Basic-Examples/09-secret-manager
cp terraform.tfvars.example terraform.tfvars
```


`terraform.tfvars` の `secret_data` は検証専用値に置き換えます。

```hcl
project_id          = "your-project-id"
region              = "asia-northeast1"
secret_data         = "replace-with-test-secret"
secret_data_version = 1
```

`terraform.tfvars` は Git 管理対象外です。

## 使用方法

```bash
terraform init
terraform fmt -check
terraform validate
terraform plan
terraform apply
```

## 確認方法

Secret metadata:

```bash
gcloud secrets describe "$(terraform output -raw secret_id)" \
  --project="$(grep project_id terraform.tfvars | cut -d'"' -f2)"
```

Secret value:

```bash
gcloud secrets versions access latest \
  --secret="$(terraform output -raw secret_id)" \
  --project="$(grep project_id terraform.tfvars | cut -d'"' -f2)"
```

## Secret を変更する場合

`secret_data` を変更するときは `secret_data_version` も増やします。

```hcl
secret_data         = "new-test-secret"
secret_data_version = 2
```

write-only value は Terraform State に保持されないため、version 値で更新タイミングを管理します。

## 削除方法

```bash
terraform destroy
```

## 注意点 / 費用

- Secret 値は Git にコミットしないでください
- 本サンプルでは `secret_data_wo` を使用し、Secret 値を Terraform State に保存しません
- Secret Manager は Secret Version の保存やアクセスに応じて料金が発生する可能性があります
- 本番 Secret ではなく検証専用値を使用してください
