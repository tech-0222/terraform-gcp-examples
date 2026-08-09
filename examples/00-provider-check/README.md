# 00 - Google Provider接続確認

TerraformからGoogle Cloudへ認証し、指定したProjectの情報を取得できることを確認する最小サンプルです。

このサンプルではGCPリソースを新規作成しません。

## 確認すること

- Application Default Credentials（ADC）で認証できる
- Terraform Google Providerを初期化できる
- 指定したProjectをTerraformから参照できる
- Project ID / Project Number / Project Nameを取得できる

## 前提

- Google Cloud CLIがインストール済み
- Terraformがインストール済み
- 検証用Google Cloud Projectが存在する
- 対象Projectを参照できるGoogleアカウントを使用する

## ファイル構成

```text
00-provider-check/
├── README.md
├── versions.tf
├── provider.tf
├── variables.tf
├── data.tf
├── outputs.tf
└── terraform.tfvars.example
```

## 1. ADCでログイン

```bash
gcloud auth application-default login
```

必要に応じてgcloudのProjectも設定します。

```bash
gcloud config set project YOUR_PROJECT_ID
```

## 2. terraform.tfvarsを作成

```bash
cp terraform.tfvars.example terraform.tfvars
```

`terraform.tfvars` の `project_id` を検証対象のProject IDへ変更します。

```hcl
project_id = "your-project-id"
region     = "asia-northeast1"
```

`terraform.tfvars` は `.gitignore` の対象です。

## 3. Terraform初期化

```bash
terraform init
```

## 4. Format / Validate

```bash
terraform fmt -check
terraform validate
```

## 5. Plan

```bash
terraform plan
```

正常に認証・参照できれば、対象Projectの情報がOutputとして確認できます。

このサンプルはリソースを作成しないため `terraform apply` は必須ではありません。

## 期待するOutput

```text
project_id     = "your-project-id"
project_name   = "..."
project_number = "..."
```

## 削除

新規リソースを作成しないため、GCP側の削除作業はありません。

ローカルのTerraform作業ファイルを消す場合は `.terraform/` 等を削除してください。
