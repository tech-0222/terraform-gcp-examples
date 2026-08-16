# 07 - リソースパラメータ対応

GKE クラスタ / ノードプールのコンソール項目対応は **[GKE-PARAMETERS.md](./GKE-PARAMETERS.md)** を正本とします。このファイルは API 有効化と準備ネットワークをまとめます。

一次情報（2026-08-16 照合）:

- [google_compute_network](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network)
- [google_compute_subnetwork](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork)
- [VPC-native clusters](https://cloud.google.com/kubernetes-engine/docs/concepts/alias-ips)

## 確認コマンド

```bash
gcloud compute networks describe tf-example-gke-vpc --format=json
gcloud compute networks subnets describe tf-example-gke-subnet \
  --region=asia-northeast1 --format=json
```

クラスタ / ノードプールの describe は `GKE-PARAMETERS.md` 側です。

## google_project_service

| 項目 | 本サンプル | Terraform |
|---|---|---|
| サービス | `container.googleapis.com` / `compute.googleapis.com` | `service` |
| destroy 時に無効化 | `false` | `disable_on_destroy` |

## ネットワーク

| 項目 | 本サンプル | Terraform | 備考 |
|---|---|---|---|
| VPC | `tf-example-gke-vpc`、カスタムモード、`REGIONAL` | `auto_create_subnetworks = false` | 未指定の auto モード既定は `true` |
| Subnet | `10.40.0.0/24`、PGA オン | `private_ip_google_access = true` | |
| Pods セカンダリ | `pods` / `10.41.0.0/16` | `secondary_ip_range` | CIDR の正本はここ。クラスタは範囲**名**だけ参照する |
| Services セカンダリ | `services` / `10.42.0.0/20` | 同上 | 同上 |

クラスタ（Standard / Spot / WI / `ip_allocation_policy`）は `GKE-PARAMETERS.md` を参照してください。CIDR をそちらへ重複記載しない。
