# 06 - Cloud Run

Cloud Run（v2）サービスを Terraform で作成・確認・削除するサンプルです。

## 確認すること

- Cloud Run v2 サービスを作成できる
- 公開 Hello イメージをデプロイできる
- HTTP で応答を確認できる（公開設定時）
- `terraform destroy` で削除できる

## 作成されるGCPリソース

| リソース | 内容 |
|---|---|
| `google_project_service` | Cloud Run / IAM API |
| `google_cloud_run_v2_service` | Hello サービス |
| `google_cloud_run_v2_service_iam_member` | 任意で `allUsers` invoker |

## 前提条件

- ADC 認証済み
- 検証用 Project（課金有効）があること

## 必要なAPI

- `run.googleapis.com`
- `iam.googleapis.com`

## 必要な権限（目安）

- Cloud Run Admin
- Service Account User（実行 SA 利用時）
- Project IAM Admin（公開設定時）

## ファイル構成

```text
06-cloud-run/
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
cd Basic-Examples/06-cloud-run
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
curl -sS "$(terraform output -raw uri)"
```

## 削除方法

```bash
terraform destroy
```

## 注意点 / 費用

- リクエスト課金です。検証後は destroy してください
- デフォルトで `allow_unauthenticated = true`（学習用の公開アクセス）です。本番では `false` を推奨
- `min_instance_count = 0` のため、アイドル時はインスタンスを縮退します
- 使用イメージ: `us-docker.pkg.dev/cloudrun/container/hello`
