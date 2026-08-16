# 01 - リソースパラメータ対応

このファイルは **本サンプルの `google_project_service`** について、GCP / `gcloud --format=json` / Terraform 属性を対応づけます。自動生成の `PARAMETER.md` とは別物です。

一次情報:

- [google_project_service](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_project_service)
- [Enabling and Disabling Services](https://cloud.google.com/service-usage/docs/enable-disable)
- [Service Usage API](https://cloud.google.com/service-usage/docs/reference/rest/v1/services)

## 凡例

| 記号 | 意味 |
|---|---|
| **明示** | コード / 変数で指定 |
| **未指定** | Provider のデフォルト |

## 確認コマンド

```bash
gcloud services list --enabled --format=json
```

## google_project_service

既定の `var.services`: `compute.googleapis.com` / `iam.googleapis.com` / `storage.googleapis.com`

| 項目 | 本サンプル | 区分 | Terraform | gcloud / API |
|---|---|---|---|---|
| Project | `var.project_id` | 明示 | `project` | 対象 Project |
| サービス名 | `for_each = var.services` | 明示 | `service` | `config.name`（`projects/PROJECT/services/SERVICE`） |
| destroy 時に無効化 | `false`（`var.disable_on_destroy`） | 明示 | `disable_on_destroy`。`false` または未設定なら destroy 後も有効のまま（[Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_project_service)） | Service Usage の disable。Terraform 専用の破壊時挙動 |
| 依存サービスも無効化 | `false`（`var.disable_dependent_services`） | 明示 | `disable_dependent_services`。`true` にすると依存 API も disable。未設定で依存があると destroy が失敗することがある | 同上 |

`disable_on_destroy = true` は、同じ構成で `google_project` 自体を管理する場合向け、と Provider は注記しています。学習サンプルでは `false` にして API を残します。
