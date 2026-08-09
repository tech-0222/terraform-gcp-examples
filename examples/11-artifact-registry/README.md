# 11 - Artifact Registry

Artifact Registry の Standard Docker Repository を Terraform で作成・確認・削除する最小サンプルです。

このサンプルでは Repository の作成までを扱い、Docker Image の build / push は対象外とします。

## 確認すること

- Artifact Registry API を有効化できる
- Standard Docker Repository を作成できる
- `gcloud artifacts repositories describe` で確認できる
- `terraform destroy` で削除できる

## 作成されるGCPリソース

| リソース | 内容 |
|---|---|
| `google_project_service` | Artifact Registry API |
| `google_artifact_registry_repository` | Standard Docker Repository |

## 前提条件

- Google Cloud CLI / Terraform がインストール済み
- ADC 認証済み
- 検証用 Project があること

## 必要なAPI

- `artifactregistry.googleapis.com`

## 必要な権限（目安）

- Artifact Registry Administrator 相当
- Service Usage Consumer

## ファイル構成

```text
11-artifact-registry/
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
cd examples/11-artifact-registry
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
gcloud artifacts repositories describe "$(terraform output -raw repository_id)" \
  --location="$(grep region terraform.tfvars | cut -d'"' -f2)" \
  --project="$(grep project_id terraform.tfvars | cut -d'"' -f2)"
```

Repository URL:

```bash
terraform output -raw docker_repository_url
```

## 削除方法

```bash
terraform destroy
```

## 注意点 / 費用

- Artifact Registry は保存容量やデータ転送などに応じて料金が発生する可能性があります
- 本サンプルでは Docker Image を push しません
- Image を push した場合は、Repository 削除前に内容と destroy 時の挙動を確認してください
- Cloud Run / GKE との連携は `scenarios/` で扱います
