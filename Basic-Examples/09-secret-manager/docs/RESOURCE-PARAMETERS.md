# 09 - リソースパラメータ対応

このファイルは **本サンプルの Secret Manager** について対応づけます。自動生成の `docs/PARAMETER.md` とは別物です。

一次情報:

- [google_secret_manager_secret](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret)
- [google_secret_manager_secret_version](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret_version)
- [Secrets](https://cloud.google.com/secret-manager/docs/reference/rest/v1/projects.secrets)
- [Write-only arguments](https://developer.hashicorp.com/terraform/language/resources/ephemeral#write-only-arguments)（Terraform 1.11+）

## 確認コマンド

```bash
gcloud secrets describe tf-example-secret --format=json
gcloud secrets versions list tf-example-secret --format=json
```

値そのものは `gcloud secrets versions access` で取れますが、ログや Git に出さないでください。

## google_secret_manager_secret.example

| 項目 | 本サンプル | 区分 | Terraform | API |
|---|---|---|---|---|
| secret_id | `tf-example-secret` | 明示 | `secret_id` | `name` の末尾 |
| レプリケーション | 自動 | 明示 | `replication { auto {} }` | `replication.automatic` |
| ユーザー管理 CMEK | 使わない | 未指定 | `customer_managed_encryption` | |

`replication.user_managed`（リージョン指定）は使いません。

## google_secret_manager_secret_version.example

| 項目 | 本サンプル | Terraform | 備考 |
|---|---|---|---|
| シークレット | 上記 Secret | `secret` | |
| 値 | `var.secret_data` | **`secret_data_wo`** | plan / state に値を残さない write-only。通常の `secret_data` は state に入る |
| バージョントリガ | `var.secret_data_version`（既定 1） | `secret_data_wo_version` | 値を変えるときはこの番号を増やす |

`secret_data_wo` は Terraform 1.11 以降の機能です。本サンプルの `versions.tf` は `>= 1.11.0` です。
