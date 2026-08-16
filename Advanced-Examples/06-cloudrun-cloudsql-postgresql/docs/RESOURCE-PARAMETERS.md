# 06 - リソースパラメータ対応

このファイルは **Cloud Run + Cloud SQL PostgreSQL + Secret Manager** について対応づけます。自動生成の `PARAMETER.md` とは別物です。

一次情報:

- [Connect from Cloud Run](https://cloud.google.com/sql/docs/postgres/connect-run)
- [google_sql_database_instance](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/sql_database_instance)
- [google_sql_user](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/sql_user)
- [google_cloud_run_v2_service](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloud_run_v2_service)
- [google_secret_manager_secret_version](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret_version)

## 確認コマンド

```bash
gcloud sql instances describe tf-adv-run-sql-pg --format=json
gcloud run services describe tf-adv-run-sql --region=asia-northeast1 --format=json
```

## Cloud SQL（Basic 13 と同型 + ユーザー）

| 項目 | 本サンプル | Terraform / 公式 |
|---|---|---|
| バージョン | `POSTGRES_15` | |
| エディション | `ENTERPRISE` | `db-f1-micro` は ENTERPRISE 必須 |
| 公開 IPv4 | オン | Cloud Run の Cloud SQL 接続（Unix ソケット / Auth Proxy 経路）用。`authorized_networks` は空 |
| バックアップ | オフ | 学習用 |
| Terraform 削除保護 | オフ | GCP 側は `settings.deletion_protection_enabled`（別フラグ、既定 false） |
| DB ユーザー | `appuser` | `password_wo` + `password_wo_version`（TF 1.11+。state に平文を残さない） |

## Secret Manager

| 項目 | 本サンプル | Terraform |
|---|---|---|
| レプリケーション | auto | `replication { auto {} }` |
| バージョン | write-only | `secret_data_wo`。同じパスワード変数を SQL user と共有 |
| IAM | `secretmanager.secretAccessor` をランタイム SA のみ | Secret スコープ |

## Cloud Run

| 項目 | 本サンプル | Terraform / 公式 |
|---|---|---|
| ランタイム SA | `tf-adv-run-sql` | `template.service_account` |
| Cloud SQL ボリューム | `/cloudsql` | `volumes.cloud_sql_instance.instances` = connection name |
| パスワード | Secret 参照 | `value_source.secret_key_ref`。環境変数に直書きしない |
| Cloud SQL IAM | `roles/cloudsql.client` | 接続に必要 |
| AR reader | リポジトリスコープ | |
| 未認証 | 既定オフ | |

Unix ソケットパスは `/cloudsql/PROJECT:REGION:INSTANCE` です。検証後は Cloud SQL を優先して destroy してください。
