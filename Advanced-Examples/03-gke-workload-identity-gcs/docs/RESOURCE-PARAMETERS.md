# 03 - リソースパラメータ対応

GKE 本体のコンソール項目対応は Basic 07 の **[GKE-PARAMETERS.md](../../../Basic-Examples/07-gke/docs/GKE-PARAMETERS.md)** を正本とします。クラスタ / ノードプールの形は Basic 07 と同型（zonal Standard、公開エンドポイント、Spot 1 ノード、WI 有効、Dataplane V2 なし）です。

このファイルは **名前・CIDR の差** と **GCS / Kubernetes 側** だけを書きます。

一次情報:

- [Workload Identity](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity)
- [google_container_cluster](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_cluster)
- [kubernetes_service_account_v1](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service_account_v1)
- [google_service_account_iam](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_service_account_iam)

## 確認コマンド

```bash
gcloud container clusters describe "$(terraform output -raw cluster_name)" \
  --zone="$(terraform output -raw cluster_location)" --format=json
gcloud storage buckets describe "gs://$(terraform output -raw bucket_name)" --format=json
```

## Basic 07 との差分（GKE）

| 項目 | Basic 07 | 本サンプル |
|---|---|---|
| クラスタ名 | `tf-example-gke` | `tf-adv-gke-wi` |
| VPC / Subnet | `10.40.0.0/24` | `10.50.0.0/24` |
| Pods / Services | `10.41.0.0/16` / `10.42.0.0/20` | `10.51.0.0/16` / `10.52.0.0/20` |
| `resource_labels.example` | `07-gke` | `03-gke-workload-identity-gcs` |
| WI / Spot / `GKE_METADATA` | あり | 同じ |

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
