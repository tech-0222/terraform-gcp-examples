# 06 - リソースパラメータ対応

このファイルは **本サンプルの Cloud Run v2** について対応づけます。自動生成の `PARAMETER.md` とは別物です。

一次情報（2026-08-16 照合）:

- [google_cloud_run_v2_service](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloud_run_v2_service)
- [google_cloud_run_v2_service_iam](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloud_run_v2_service_iam)
- [Cloud Run Admin API Service](https://cloud.google.com/run/docs/reference/rest/v2/projects.locations.services)
- [Container runtime contract（CPU）](https://cloud.google.com/run/docs/configuring/cpu)

## 確認コマンド

```bash
gcloud run services describe "$(terraform output -raw service_name)" \
  --region="$(terraform output -raw location)" --format=json
```

## google_cloud_run_v2_service.hello

| 項目 | 本サンプル | 区分 | Terraform | API / 備考 |
|---|---|---|---|---|
| 名前 | `tf-example-hello` | 明示 | `name` | `name` |
| リージョン | `asia-northeast1` | 明示 | `location` | ロケーション |
| イングレス | すべて許可 | 明示 | `ingress = "INGRESS_TRAFFIC_ALL"`。他は `INTERNAL_ONLY` / `INTERNAL_LOAD_BALANCER` | |
| Terraform 削除保護 | オフ | 明示 | `deletion_protection = false`。**Provider 既定は `true`**（destroy が失敗する） | Terraform 専用。GCP コンソールの削除保護とは別 |
| イメージ | `us-docker.pkg.dev/cloudrun/container/hello` | 明示 | `template.containers.image` | |
| CPU | `1` | 明示 | `resources.limits.cpu`。対応値は `'1','2','4','6','8'` | |
| メモリ | `512Mi` | 明示 | `resources.limits.memory` | CPU 4 以上はメモリ下限あり |
| 最小インスタンス | `0` | 明示 | `template.scaling.min_instance_count` | 課金抑制 |
| 最大インスタンス | `2` | 明示 | `template.scaling.max_instance_count` | |
| 認証 | 未指定（既定は認証必要） | 未指定 | IAM で制御 | |

## google_cloud_run_v2_service_iam_member.public

`allow_unauthenticated = true` のとき `roles/run.invoker` を `allUsers` に付与します。公開デモ用です。`false` ならこのリソースは作りません。
