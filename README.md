# terraform-gcp-examples

Terraformを使用してGoogle Cloud（GCP）の各種リソースを作成・検証するためのサンプルコード集です。

現在はPrivateリポジトリで検証を進め、コードと手順が安定した段階でPublic化することを想定しています。

## 方針

- 各サンプルは可能な限り独立して実行できる構成にする
- `terraform init` → `terraform validate` → `terraform plan` → `terraform apply` → 動作確認 → `terraform destroy` まで検証する
- 認証情報・Project固有情報・SecretはGitにコミットしない
- 実値は `terraform.tfvars`、公開用サンプルは `terraform.tfvars.example` を使用する
- Terraform StateはGitにコミットしない
- まずは分かりやすい最小構成から作成し、徐々に実践的な構成へ広げる

## ディレクトリ構成

```text
terraform-gcp-examples/
├── README.md
├── .gitignore
├── docs/
│   └── CONVENTIONS.md
└── examples/
    ├── README.md
    ├── 00-provider-check/
    ├── 01-project-service/
    ├── 02-network/
    ├── 03-cloud-storage/
    ├── 04-compute-engine/
    ├── 05-iam/
    ├── 06-cloud-run/
    └── 07-gke/
```

## サンプル一覧

| No. | ディレクトリ | 内容 | 状態 |
|---|---|---|---|
| 00 | `00-provider-check` | Google Provider・ADC・Project参照確認 | 実装済み |
| 01 | `01-project-service` | Service APIの有効化 | 準備中 |
| 02 | `02-network` | VPC / Subnet / Firewall | 準備中 |
| 03 | `03-cloud-storage` | Cloud Storage | 準備中 |
| 04 | `04-compute-engine` | Compute Engine | 準備中 |
| 05 | `05-iam` | Service Account / IAM | 準備中 |
| 06 | `06-cloud-run` | Cloud Run | 準備中 |
| 07 | `07-gke` | Google Kubernetes Engine | 準備中 |

## 前提

- Google Cloudアカウント
- 検証に使用するGoogle Cloud Project
- Google Cloud CLI（`gcloud`）
- Terraform

Terraformのバージョン条件は各サンプルの `versions.tf` を参照してください。

## 最初に試す

まずはリソースを作成しない `00-provider-check` で、TerraformからGoogle Cloudへアクセスできることを確認します。

```bash
cd examples/00-provider-check

gcloud auth application-default login

cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars の project_id を自分のProject IDへ変更

terraform init
terraform fmt -check
terraform validate
terraform plan
```

詳細は `examples/00-provider-check/README.md` を参照してください。

## 注意

GCPリソースによっては利用料金が発生します。各サンプルでは作成するリソースと削除方法を明記し、検証後は不要なリソースを `terraform destroy` 等で削除する方針です。
