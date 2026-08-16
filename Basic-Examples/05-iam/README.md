# 05 - IAM / Service Account

Service Account を作成し、Project に最小権限の IAM を付与するサンプルです。

## 確認すること

- Service Account を作成できる
- `google_project_iam_member`（加算型）でロールを付与できる
- `terraform destroy` で削除できる

## 作成されるGCPリソース

| リソース | 内容 |
|---|---|
| `google_project_service` | IAM API |
| `google_service_account` | 検証用 SA |
| `google_project_iam_member` | デフォルト `roles/storage.objectViewer` |

## 前提条件

- ADC 認証済み
- 検証用 Project があること

## 必要なAPI

- `iam.googleapis.com`

## 必要な権限（目安）

- Service Account Admin
- Project IAM Admin（または相当）

## ファイル構成

```text
05-iam/
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
cd Basic-Examples/05-iam
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
gcloud iam service-accounts describe "$(terraform output -raw service_account_email)"
gcloud projects get-iam-policy "$(grep project_id terraform.tfvars | cut -d'"' -f2)" \
  --flatten="bindings[].members" \
  --filter="bindings.members:$(terraform output -raw service_account_email)" \
  --format="table(bindings.role)"
```

## 削除方法

```bash
terraform destroy
```

## 注意点 / 費用

- Service Account / IAM 自体に追加料金は通常かかりません
- **Service Account Key JSON は作成しません**（鍵の長期保管を避ける）
- `google_project_iam_binding`（上書き型）は使わず、加算型の `member` を使います
- デフォルト権限は閲覧系の `roles/storage.objectViewer` です
