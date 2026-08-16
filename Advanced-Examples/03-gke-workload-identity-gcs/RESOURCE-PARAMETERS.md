# 03 - リソースパラメータ対応

このファイルは **GKE Workload Identity + GCS 書き込み Job** について対応づけます。自動生成の `PARAMETER.md` とは別物です。

一次情報（2026-08-16 照合）:

- [Workload Identity](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity)
- [google_container_cluster](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_cluster)
- [kubernetes_service_account_v1](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service_account_v1)
- [google_service_account_iam](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_service_account_iam)

## 確認コマンド

```bash
gcloud container clusters describe tf-adv-gke-wi --zone=asia-northeast1-a --format=json
gcloud storage buckets describe "gs://tf-adv-gke-wi-PROJECT_ID" --format=json
```

## ネットワーク / GKE（Basic 07 と同型）

| 項目 | 本サンプル | Terraform / 公式 |
|---|---|---|
| クラスタ | zonal `asia-northeast1-a` | `location` がゾーンなら zonal |
| デフォルトプール | 削除 | `remove_default_node_pool` + `initial_node_count` |
| Workload Identity | `{project}.svc.id.goog` | `workload_identity_config.workload_pool` |
| ノード | Spot / `GKE_METADATA` | WI 利用時はノードの `workload_metadata_config.mode = GKE_METADATA` が必要 |
| Pods/Services CIDR | `10.51.0.0/16` / `10.52.0.0/20` | VPC-native セカンダリ |

## GCS と IAM

| 項目 | 本サンプル | Terraform / 公式 |
|---|---|---|
| UBLA / PAP | オン / `enforced` | Provider の UBLA 既定は false、PAP 既定は inherited |
| バケット IAM | `roles/storage.objectAdmin` を GCP SA のみ | バケットスコープ（Project 全体ではない） |
| WI バインド | `roles/iam.workloadIdentityUser` | メンバーは `serviceAccount:PROJECT.svc.id.goog[NS/KSA]` |

## Kubernetes

| 項目 | 本サンプル | 公式 |
|---|---|---|
| KSA annotation | `iam.gke.io/gcp-service-account` = GCP SA メール | WI の標準 annotation |
| Job | `gsutil cp` でオブジェクト作成 | `wait_for_completion = true`。完了待ちは Terraform の挙動 |

JSON 鍵は使いません。検証後は GKE を必ず destroy してください。
