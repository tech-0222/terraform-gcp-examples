# 12 - リソースパラメータ対応

このファイルは **本サンプルの BigQuery Dataset / Table** について対応づけます。自動生成の `docs/PARAMETER.md` とは別物です。

一次情報:

- [google_bigquery_dataset](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/bigquery_dataset)
- [google_bigquery_table](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/bigquery_table)
- [datasets](https://cloud.google.com/bigquery/docs/reference/rest/v2/datasets)
- [tables](https://cloud.google.com/bigquery/docs/reference/rest/v2/tables)

## 確認コマンド

```bash
bq show --format=prettyjson tf_example_dataset
bq show --format=prettyjson tf_example_dataset.messages
```

`bq` の代わりに:

```bash
gcloud alpha bq datasets describe tf_example_dataset --format=json
```

（alpha の有無は環境による。REST / コンソールでも可）

## google_bigquery_dataset.example

| 項目 | 本サンプル | 区分 | Terraform | API |
|---|---|---|---|---|
| dataset_id | `tf_example_dataset` | 明示 | `dataset_id`（英数字と `_` のみ） | `datasetReference.datasetId` |
| ロケーション | `asia-northeast1` | 明示 | `location`。作成後の変更は不可（replace） | `location` |
| 表示名 | Terraform Example Dataset | 明示 | `friendly_name` | `friendlyName` |
| destroy 時に中身削除 | `true` | 明示 | `delete_contents_on_destroy`。Terraform 専用。未指定時は中にテーブルがあると destroy 失敗 | |

## google_bigquery_table.example

| 項目 | 本サンプル | Terraform | 備考 |
|---|---|---|---|
| table_id | `messages` | `table_id` | |
| スキーマ | id STRING REQUIRED / message / created_at TIMESTAMP | `schema`（JSON） | |
| Terraform 削除保護 | オフ | `deletion_protection = false` | Provider によっては既定 true |

パーティショニング / クラスタリングは付けていません。
