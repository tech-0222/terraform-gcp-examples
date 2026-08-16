# 00 - リソースパラメータ対応

このファイルは **本サンプルの `data.google_project.current`** について、GCP / `gcloud --format=json` / Terraform 属性を対応づけます。自動生成の `PARAMETER.md` とは別物です。

本サンプルはリソースを作成しません。Project の参照確認だけです。

一次情報（2026-08-16 照合）:

- [data.google_project](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/project)
- [projects.get](https://cloud.google.com/resource-manager/reference/rest/v1/projects)

## 凡例

| 記号 | 意味 |
|---|---|
| **明示** | コード / 変数で指定 |
| **未指定** | Provider / GCP のデフォルト |
| **出力** | 読み取り専用 |

## 確認コマンド

```bash
gcloud projects describe "$(terraform output -raw project_id)" --format=json
```

## data.google_project

| 項目 | 本サンプル | 区分 | Terraform | gcloud パス |
|---|---|---|---|---|
| Project ID | `var.project_id` | 明示 | `project_id`。省略時は provider の project | `projectId` |
| 表示名 | API から取得 | 出力 | `name` | `name` |
| 番号 | API から取得 | 出力 | `number` | `projectNumber` |
| リージョン（provider） | `asia-northeast1` | 明示 | provider `region`。Project リソースのフィールドではない | — |

`data.google_project` は Resource Manager の Project を読むだけです。compute / IAM リソースは作りません。
