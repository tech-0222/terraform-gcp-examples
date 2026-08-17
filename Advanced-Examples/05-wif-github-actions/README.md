# 05 - Workload Identity Federation（GitHub Actions）

GitHub Actions から **JSON 鍵なし** で GCP の Service Account を借用するための WIF（OIDC）設定サンプルです。

## 関係するサービス

| サービス | 役割 |
|---|---|
| IAM (WIF) | Workload Identity Pool / Provider（GitHub OIDC） |
| IAM | SA + `roles/iam.workloadIdentityUser` |
| Cloud Storage | 最小権限デモ用バケット |
| GitHub Actions | `google-github-actions/auth`（例: `workflow.example.yml`） |

## 作成されるGCPリソース

リソースの明示設定と公式ドキュメント上の既定値の対応は `docs/RESOURCE-PARAMETERS.md` を参照してください。`docs/PARAMETER.md` は terraform-docs の自動生成です。


| リソース | 内容 |
|---|---|
| `google_iam_workload_identity_pool` | GitHub 用プール |
| `google_iam_workload_identity_pool_provider` | `token.actions.githubusercontent.com` |
| `google_service_account` | Actions が借用する SA |
| `google_service_account_iam_member` | `attribute.repository=<org/repo>` → WI User |
| `google_storage_bucket` (+ object / IAM) | 読み取りデモ |

`attribute_condition` と IAM `principalSet` の両方で **指定リポジトリのみ** に制限します。

## 前提条件

- ADC 認証済み
- 検証用 Project
- GitHub リポジトリ名（default: `tech-0222/terraform-gcp-examples`）

## ファイル構成

```text
05-wif-github-actions/
├── README.md
├── docs/
│   ├── PARAMETER.md              # terraform-docs（自動生成。手動編集しない）
│   └── RESOURCE-PARAMETERS.md    # コンソール / API / Terraform の対応（手書き）
├── DEPENDENCY-GRAPH.svg          # terraform graph（自動生成。手動編集しない）
├── .terraform.lock.hcl
├── versions.tf
├── provider.tf
├── variables.tf
├── main.tf
├── outputs.tf
├── workflow.example.yml          # GitHub Actions のテンプレート
└── terraform.tfvars.example
```

リポジトリ直下の `.github/workflows/wif-demo.yml` は本モジュール apply 後に手動実行する検証用 workflow です。

## 使用方法

```bash
cd Advanced-Examples/05-wif-github-actions
cp terraform.tfvars.example terraform.tfvars
# project_id / github_repository を設定

terraform init
terraform apply
terraform output
```

GitHub Actions で試す場合:

1. 本リポジトリには検証用の `.github/workflows/wif-demo.yml` あり（`workflow_dispatch`）
2. 先にこのモジュールを `terraform apply` して WIF / SA / demo bucket を用意する
3. Actions の **wif-demo** を手動実行（`id-token: write` 必須）

テンプレートのみ欲しい場合は同ディレクトリの `workflow.example.yml` を参照してください。

## 確認方法（ローカル / apply 直後）

```bash
gcloud iam workload-identity-pools describe "$(terraform output -raw workload_identity_pool_id)"

gcloud iam workload-identity-pools providers describe \
  "$(terraform output -raw workload_identity_provider_name)"

gcloud storage cat "gs://$(terraform output -raw demo_bucket_name)/hello-wif.txt"
```

フル経路（GitHub → STS → SA）の確認は workflow 実行が必要です。

## 削除方法

```bash
terraform destroy
```

## 注意点 / 費用

- WIF 自体の課金はほぼ無視できる水準。デモ用 GCS は検証後に destroy
- Provider の `attribute_condition` を緩めすぎない（`*` や org 全体は避ける）
- SA 鍵（JSON）は作成しません
- Private リポジトリでも OIDC は利用できます（Actions の権限設定に注意）
