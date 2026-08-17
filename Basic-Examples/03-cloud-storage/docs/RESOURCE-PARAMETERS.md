# 03 - リソースパラメータ対応

このファイルは **本サンプルの `google_storage_bucket`** について、GCP / `gcloud --format=json` / Terraform 属性を対応づけます。自動生成の `docs/PARAMETER.md` とは別物です。

一次情報:

- [google_storage_bucket](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket)
- [Buckets](https://cloud.google.com/storage/docs/json_api/v1/buckets)
- [Uniform bucket-level access](https://cloud.google.com/storage/docs/uniform-bucket-level-access)
- [Public access prevention](https://cloud.google.com/storage/docs/public-access-prevention)

## 凡例

| 記号 | 意味 |
|---|---|
| **明示** | コード / 変数で指定 |
| **未指定** | Provider / GCP のデフォルト |
| **再作成 ○** | 変更で replace になりやすい（名前・location など） |

## 確認コマンド

```bash
gcloud storage buckets describe "gs://$(terraform output -raw bucket_name)" --format=json
```

output 名が無い場合は `<prefix>-<project_id>` です。

## google_storage_bucket.example

| 項目 | 本サンプル | 区分 | 再作成 | Terraform | gcloud / API |
|---|---|---|---|---|---|
| 名前 | `tf-example-<project_id>` | 明示 | ○ | `name`（グローバル一意） | `name` |
| ロケーション | `ASIA-NORTHEAST1` | 明示 | ○ | `location`。リージョン名は大文字が通例 | `location` |
| 均一なバケットレベルアクセス | オン | 明示 | − | `uniform_bucket_level_access = true`。Provider 既定は `false`（ACL 併用） | `iamConfiguration.uniformBucketLevelAccess.enabled` |
| 公開アクセス防止 | `enforced` | 明示 | − | `public_access_prevention`。既定は `inherited`（組織ポリシーに従う） | `iamConfiguration.publicAccessPrevention` |
| バージョニング | オフ | 明示 | − | `versioning.enabled = false` | `versioning.enabled` |
| force_destroy | `true`（変数既定） | 明示 | − | Terraform 専用。`true` なら destroy 前にオブジェクトを削除。Provider 既定は `false` | API の常設フィールドではない |
| ストレージクラス | 未指定 | 未指定 | − | `storage_class`。未指定時 `STANDARD` | `storageClass` |
| Soft delete | 未指定 | 未指定 | − | `soft_delete_policy` | `softDeletePolicy` |

ラベルは `env=test` ほか。Provider 6.x では `goog-terraform-provisioned=true` が付くことがあります。
