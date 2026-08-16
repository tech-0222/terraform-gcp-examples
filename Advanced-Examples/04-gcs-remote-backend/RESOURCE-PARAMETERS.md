# 04 - リソースパラメータ対応

このファイルは **Terraform GCS Remote Backend 用バケット** について対応づけます。自動生成の `PARAMETER.md` とは別物です。ネストした `demo/` は [demo/RESOURCE-PARAMETERS.md](./demo/RESOURCE-PARAMETERS.md) です。

一次情報:

- [GCS backend](https://developer.hashicorp.com/terraform/language/backend/gcs)
- [google_storage_bucket](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket)
- [Object Versioning](https://cloud.google.com/storage/docs/object-versioning)

## 確認コマンド

```bash
gcloud storage buckets describe "gs://$(terraform output -raw state_bucket_name)" --format=json
```

## google_storage_bucket.tfstate

| 項目 | 本サンプル | 区分 | Terraform / 公式 |
|---|---|---|---|
| 名前 | `tf-adv-tfstate-<project_id>` | 明示 | グローバル一意 |
| location | `ASIA-NORTHEAST1` | 明示 | リージョン。変更は replace |
| UBLA | オン | 明示 | 既定 false |
| PAP | `enforced` | 明示 | 既定 `inherited` |
| バージョニング | **オン** | 明示 | State の誤上書き復旧用。Basic 03 はオフ |
| force_destroy | `true`（学習用） | 明示 | Terraform 専用。既定 false。本番の state バケットでは通常 false |

GCS backend のロックはバケットのオブジェクト世代で行います。親モジュールを destroy する前に **demo 側を先に destroy** してください（README の順）。
