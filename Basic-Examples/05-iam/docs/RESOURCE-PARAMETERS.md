# 05 - リソースパラメータ対応

このファイルは **本サンプルの Service Account と Project IAM** について対応づけます。自動生成の `docs/PARAMETER.md` とは別物です。

一次情報:

- [google_service_account](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_service_account)
- [google_project_iam_member](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_project_iam)
- [Service accounts](https://cloud.google.com/iam/docs/service-account-overview)
- [IAM policy](https://cloud.google.com/iam/docs/overview)

## 確認コマンド

```bash
gcloud iam service-accounts describe "$(terraform output -raw service_account_email)" --format=json
gcloud projects get-iam-policy YOUR_PROJECT_ID --format=json
```

## google_service_account.example

| 項目 | 本サンプル | 区分 | 再作成 | Terraform | gcloud パス |
|---|---|---|---|---|---|
| account_id | `tf-example-sa` | 明示 | ○ | `account_id`（6–30 文字。メールの `@` より前） | `email` のローカル部 |
| 表示名 | `TF Example Service Account` | 明示 | − | `display_name` | `displayName` |
| 説明 | サンプル用文字列 | 明示 | − | `description` | `description` |
| メール | `{account_id}@{project}.iam.gserviceaccount.com` | 出力 | − | `email` | `email` |
| キー | 作らない | 未指定 | − | `google_service_account_key` は使わない | — |

Service Account Key の長期保存は避けます（[GCP の推奨](https://cloud.google.com/iam/docs/best-practices-service-accounts)）。

## google_project_iam_member.example

| 項目 | 本サンプル | Terraform | 備考 |
|---|---|---|---|
| ロール | `roles/storage.objectViewer` | `role` | 最小権限の例 |
| メンバー | 上記 SA | `member = "serviceAccount:..."` | |
| バインディング方式 | 加算 | `google_project_iam_member` | `google_project_iam_binding` / `policy` は他メンバーを上書きしうる。Provider も member（additive）を推奨 |

IAM 条件（`condition`）は付けていません。
