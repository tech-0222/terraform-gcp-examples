# terraform-gcp-examples

Terraformを使用してGoogle Cloud（GCP）の各種リソースを作成・検証するサンプルコード集です。

現在はPrivateリポジトリで検証を進め、コードと手順が安定した段階でPublic化することを想定しています。

## 方針

- **基本**は `Basic-Examples/`、**応用・複合**は `Advanced-Examples/` に分ける
- 各サンプル / シナリオは可能な限り独立した Root Module にする
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
├── .terraform-docs.yml           # terraform-docs 設定
├── .terraform-graph.conf         # terraform graph 設定
├── scripts/
│   ├── generate-terraform-docs.sh
│   ├── generate-terraform-graphs.sh
│   └── lib/
├── docs/
│   └── CONVENTIONS.md
├── Basic-Examples/                     # 基本（単体・最小）
│   ├── README.md
│   └── <sample>/
│       ├── PARAMETER.md          # terraform-docs 自動生成
│       ├── DEPENDENCY-GRAPH.svg  # terraform graph 自動生成
│       └── ...
└── Advanced-Examples/                    # 応用（複数サービス連携）
    └── README.md
```

## Basic-Examples（基本）一覧

| No. | ディレクトリ | 内容 | 状態 |
|---|---|---|---|
| 00 | `00-provider-check` | Google Provider・ADC・Project参照確認 | 実装済み |
| 01 | `01-project-service` | Service APIの有効化 | 実装済み |
| 02 | `02-network` | VPC / Subnet / Firewall | 実装済み |
| 03 | `03-cloud-storage` | Cloud Storage | 実装済み |
| 04 | `04-compute-engine` | Compute Engine | 実装済み |
| 05 | `05-iam` | Service Account / IAM | 実装済み |
| 06 | `06-cloud-run` | Cloud Run | 実装済み |
| 07 | `07-gke` | Google Kubernetes Engine | 実装済み |
| 08 | `08-cloud-dns` | Private Cloud DNS / A Record | 実装済み |
| 09 | `09-secret-manager` | Secret / Secret Version | 実装済み |
| 10 | `10-pubsub` | Topic / Pull Subscription | 実装済み |
| 11 | `11-artifact-registry` | Standard Docker Repository | 実装済み |
| 12 | `12-bigquery` | Dataset / Table | コード準備済み（未検証） |
| 13 | `13-cloud-sql-postgresql` | Cloud SQL for PostgreSQL / Database | コード準備済み（未検証） |
| 14 | `14-cloud-kms` | KeyRing / CryptoKey | コード準備済み（未検証） |
| 15 | `15-cloud-monitoring` | Alert Policy / 任意のEmail Notification Channel | コード準備済み（未検証） |

## Advanced-Examples（応用）

| No. | ディレクトリ | 内容 | 状態 |
|---|---|---|---|
| 01 | `01-gce-iap-vpc` | GCE Spot + 専用 VPC + IAP SSH / OS Login IAM | 実装済み |
| 02 | `02-cloudrun-artifact-registry` | Cloud Run + Artifact Registry + ランタイム SA / invoker IAM | 実装済み |
| 03 | `03-gke-workload-identity-gcs` | GKE Spot + Workload Identity + GCS 書き込み | 実装済み |
| 04 | `04-gcs-remote-backend` | GCS Remote Backend（State）+ demo | 実装済み |
| 05 | `05-wif-github-actions` | Workload Identity Federation（GitHub Actions OIDC） | 実装済み |

詳細は `Advanced-Examples/README.md` を参照してください。

## 前提

- Google Cloudアカウント
- 検証に使用するGoogle Cloud Project
- Google Cloud CLI（`gcloud`）
- Terraform

Terraformのバージョン条件は各サンプルの `versions.tf` を参照してください。

## 最初に試す

まずはリソースを作成しない `00-provider-check` で、TerraformからGoogle Cloudへアクセスできることを確認します。

```bash
cd Basic-Examples/00-provider-check

gcloud auth application-default login

cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars の project_id を自分のProject IDへ変更

terraform init
terraform fmt -check
terraform validate
terraform plan
```

詳細は `Basic-Examples/00-provider-check/README.md` を参照してください。

## PARAMETER.md / DEPENDENCY-GRAPH.svg（ローカル生成）

各 root module（`Basic-Examples/*` / `Advanced-Examples/*`）に次を生成します。**GitHub Actions は使いません。** ローカルでスクリプトを実行してください。

| 成果物 | 内容 | 生成コマンド |
|---|---|---|
| `PARAMETER.md` | requirements / providers / resources / inputs / outputs | `./scripts/generate-terraform-docs.sh --all` |
| `DEPENDENCY-GRAPH.svg` | `terraform graph` の依存関係図 | `./scripts/generate-terraform-graphs.sh --all` |

前提ツール:

- [terraform-docs](https://terraform-docs.io/)（検証環境: v0.24.0）
- Terraform
- Graphviz（`dot` コマンド）

個別実行例:

```bash
./scripts/generate-terraform-docs.sh Basic-Examples/04-compute-engine
./scripts/generate-terraform-graphs.sh Basic-Examples/04-compute-engine
```

これらのファイルは自動生成です。手動編集しないでください。`.tf` を変更したら再生成します。

## 注意

GCPリソースによっては利用料金が発生します。各サンプルでは作成するリソースと削除方法を明記し、検証後は不要なリソースを `terraform destroy` 等で削除する方針です。
