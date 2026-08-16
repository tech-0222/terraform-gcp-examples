# 11 - リソースパラメータ対応

このファイルは **本サンプルの Artifact Registry** について対応づけます。自動生成の `PARAMETER.md` とは別物です。

一次情報:

- [google_artifact_registry_repository](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/artifact_registry_repository)
- [Repositories](https://cloud.google.com/artifact-registry/docs/reference/rest/v1/projects.locations.repositories)
- [Repository modes](https://cloud.google.com/artifact-registry/docs/repositories)

## 確認コマンド

```bash
gcloud artifacts repositories describe tf-example-docker \
  --location=asia-northeast1 --format=json
```

## google_artifact_registry_repository.example

| 項目 | 本サンプル | 区分 | Terraform | API |
|---|---|---|---|---|
| repository_id | `tf-example-docker` | 明示 | `repository_id` | `name` の末尾 |
| ロケーション | `asia-northeast1` | 明示 | `location` | |
| フォーマット | `DOCKER` | 明示 | `format` | `format` |
| 説明 | 変数既定 | 明示 | `description` | `description` |
| モード | 未指定 | 未指定 | `mode`。未指定は **STANDARD_REPOSITORY**（標準）。REMOTE / VIRTUAL ではない | `mode` |
| 不変タグ | 未指定 | 未指定 | Docker の `cleanup_policies` / 不変設定は未使用 | |

イメージの push はこのサンプルでは行いません。リポジトリ作成のみです。
