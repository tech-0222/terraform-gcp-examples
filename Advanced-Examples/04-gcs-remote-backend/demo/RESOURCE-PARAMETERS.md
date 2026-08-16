# 04 demo - リソースパラメータ対応

親で作った GCS バケットを Terraform backend にし、小さなデモバケットを管理します。

一次情報:

- [GCS backend](https://developer.hashicorp.com/terraform/language/backend/gcs)
- [google_storage_bucket](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket)

## backend

`backend.hcl`（gitignore）で `bucket` と `prefix = "demo"` を指定します。`backend.hcl.example` はプレースホルダです。

## google_storage_bucket.demo

| 項目 | 本サンプル | Terraform |
|---|---|---|
| 名前 | `tf-adv-remote-demo-<project_id>` | `demo_bucket_prefix` 既定 `tf-adv-remote-demo` |
| location | `ASIA-NORTHEAST1` | 親の state バケットと同じリージョン想定 |
| UBLA / PAP | true / enforced | 親と同じ |
| versioning | 未指定（オフ） | state 用ではないデモオブジェクト |
| force_destroy | true | 学習用 |
