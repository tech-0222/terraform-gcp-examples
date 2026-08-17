# 02 - リソースパラメータ対応

このファイルは **Cloud Run + Artifact Registry + ランタイム SA** について対応づけます。自動生成の `docs/PARAMETER.md` とは別物です。

一次情報:

- [google_cloud_run_v2_service](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloud_run_v2_service)
- [google_artifact_registry_repository](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/artifact_registry_repository)
- [Cloud Run identity](https://cloud.google.com/run/docs/securing/service-identity)

## 確認コマンド

```bash
gcloud artifacts repositories describe tf-adv-run --location=asia-northeast1 --format=json
gcloud run services describe tf-adv-hello --region=asia-northeast1 --format=json
```

## Artifact Registry

| 項目 | 本サンプル | Terraform / 公式 |
|---|---|---|
| format | `DOCKER` | `format` |
| mode | 未指定 | 既定 `STANDARD_REPOSITORY` |
| 読み取り IAM | ランタイム SA に `roles/artifactregistry.reader` | リポジトリスコープの member |

## ランタイム SA

Cloud Run の `template.service_account` に専用 SA を指定します。未指定だとデフォルト Compute Engine SA になります。鍵 JSON は作りません。

## Cloud Run v2

| 項目 | 本サンプル | Terraform / 公式 |
|---|---|---|
| ingress | `INGRESS_TRAFFIC_ALL` | 受信元。内部のみは `INTERNAL_ONLY` など |
| deletion_protection | `false` | Provider 既定は **true** |
| CPU / メモリ | `1` / `512Mi` | CPU は `'1','2','4','6','8'` |
| スケール | min 0 / max 2 | 学習用に最小 0 |
| 初回イメージ | 公開 hello | apply 後に AR へ push して差し替える想定 |
| 未認証 invoker | 既定オフ | `allow_unauthenticated = false`。Basic 06 は既定オン |

`invoker_member` が空でなければ `roles/run.invoker` をその Principal に付けます。
