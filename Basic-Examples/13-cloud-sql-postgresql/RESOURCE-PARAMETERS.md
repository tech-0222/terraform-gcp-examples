# 13 - リソースパラメータ対応

このファイルは **本サンプルの Cloud SQL for PostgreSQL** について対応づけます。自動生成の `PARAMETER.md` とは別物です。

一次情報（2026-08-16 照合）:

- [google_sql_database_instance](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/sql_database_instance)
- [google_sql_database](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/sql_database)
- [SQL Admin API instances](https://cloud.google.com/sql/docs/postgres/admin-api/rest/v1beta4/instances)

## 確認コマンド

```bash
gcloud sql instances describe tf-example-postgres --format=json
gcloud sql databases list --instance=tf-example-postgres --format=json
```

## google_sql_database_instance.example

| 項目 | 本サンプル | 区分 | Terraform | 公式の注意 |
|---|---|---|---|---|
| 名前 | `tf-example-postgres` | 明示 | `name` | 名前の再利用には待ち時間がある |
| リージョン | `asia-northeast1` | 明示 | `region` | |
| バージョン | `POSTGRES_15` | 明示 | `database_version` | |
| エディション | `ENTERPRISE` | 明示 | `settings.edition`。**`db-f1-micro` は ENTERPRISE が必要**。POSTGRES_16+ で edition 未指定だと ENTERPRISE_PLUS になり、shared-core は無効 | |
| ティア | `db-f1-micro` | 明示 | `settings.tier` | 共有コア。学習用 |
| HA | ZONAL | 明示 | `availability_type = "ZONAL"`。REGIONAL は HA | |
| ディスク | PD_SSD 10 GB、自動拡張オフ | 明示 | `disk_type` / `disk_size` / `disk_autoresize = false`。`disk_autoresize` の Provider 既定は **true** | 縮小は不可 |
| バックアップ | オフ | 明示 | `backup_configuration.enabled = false` | 学習用。本番では非推奨 |
| 公開 IPv4 | オン | 明示 | `ip_configuration.ipv4_enabled = true`。private_network も IPv4 も無いと作成できない | 承認済みネットワークは未設定（外部からの接続は制限されることが多い） |
| Terraform 削除保護 | オフ | 明示 | `deletion_protection = false`。**GCP 側の削除保護は `settings.deletion_protection_enabled`（既定 false）** で別 | |
| ユーザー / パスワード | 作らない | 未指定 | `google_sql_user` なし | |

## google_sql_database.example

| 項目 | 本サンプル | Terraform |
|---|---|---|
| 名前 | `appdb` | `name` |
| 文字セット | 未指定 | PostgreSQL 既定 |

Cloud SQL は起動中課金されます。検証後は必ず destroy してください。
