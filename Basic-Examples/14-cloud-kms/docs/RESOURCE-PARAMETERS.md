# 14 - リソースパラメータ対応

このファイルは **本サンプルの Cloud KMS KeyRing / CryptoKey** について対応づけます。自動生成の `docs/PARAMETER.md` とは別物です。

一次情報:

- [google_kms_key_ring](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/kms_key_ring)
- [google_kms_crypto_key](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/kms_crypto_key)
- [Key rings](https://cloud.google.com/kms/docs/reference/rest/v1/projects.locations.keyRings)
- [KMS resource deletion](https://cloud.google.com/kms/docs/unversion)

## 確認コマンド

```bash
gcloud kms keyrings describe "$(terraform output -raw key_ring_name)" \
  --location=global --format=json
gcloud kms keys describe tf-example-key \
  --keyring="$(terraform output -raw key_ring_name)" --location=global --format=json
```

## google_kms_key_ring.example

| 項目 | 本サンプル | 区分 | Terraform | 公式 |
|---|---|---|---|---|
| 名前 | `tf-example-keyring-<project_id>` | 明示 | `name` | |
| ロケーション | `global` | 明示 | `location`。変更は新リソース | |

**KeyRing は GCP 上で完全削除できません。** `terraform destroy` は Terraform state から外しますが、同名の KeyRing は Project に残ります。再 apply は import か別名が必要です。

## google_kms_crypto_key.example

| 項目 | 本サンプル | 区分 | Terraform | API |
|---|---|---|---|---|
| 名前 | `tf-example-key` | 明示 | `name` | |
| 用途 | `ENCRYPT_DECRYPT` | 明示 | `purpose`。作成後変更不可 | `purpose` |
| ローテーション | 未指定 | 未指定 | `rotation_period` | |
| 初期バージョン | 作る | 未指定 | `skip_initial_version_creation` 未使用 | |

CryptoKey の destroy は即時消去ではなく、スケジュール削除になります（[Destroying keys](https://cloud.google.com/kms/docs/destroy-restore)）。学習後も KeyRing 名の衝突に注意してください。
