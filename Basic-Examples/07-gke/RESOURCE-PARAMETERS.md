# 07 - リソースパラメータ対応

このファイルは **本サンプルの GKE（zonal Standard + Spot ノードプール）** について対応づけます。自動生成の `PARAMETER.md` とは別物です。

一次情報（2026-08-16 照合）:

- [google_container_cluster](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_cluster)
- [google_container_node_pool](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_node_pool)
- [GKE release channels](https://cloud.google.com/kubernetes-engine/docs/concepts/release-channels)
- [Spot VMs on GKE](https://cloud.google.com/kubernetes-engine/docs/concepts/spot-vms)
- [VPC-native clusters](https://cloud.google.com/kubernetes-engine/docs/concepts/alias-ips)

## 確認コマンド

```bash
gcloud container clusters describe "$(terraform output -raw cluster_name)" \
  --zone="$(terraform output -raw cluster_location)" --format=json
```

## ネットワーク

| 項目 | 本サンプル | Terraform |
|---|---|---|
| VPC | カスタムモード、`REGIONAL` | `auto_create_subnetworks = false` |
| Subnet | `10.40.0.0/24`、PGA オン | `private_ip_google_access = true` |
| Pods セカンダリ | `pods` / `10.41.0.0/16` | `secondary_ip_range` |
| Services セカンダリ | `services` / `10.42.0.0/20` | 同上 |

VPC-native（エイリアス IP）ではクラスタの `ip_allocation_policy` がセカンダリ範囲名を参照します。

## google_container_cluster.primary

| 項目 | 本サンプル | 区分 | Terraform | 備考 |
|---|---|---|---|---|
| 名前 | `tf-example-gke` | 明示 | `name` | |
| ロケーション | `asia-northeast1-a`（ゾーン） | 明示 | `location`。ゾーンなら **zonal**、リージョンなら regional | |
| デフォルトプール削除 | する | 明示 | `remove_default_node_pool = true` のとき `initial_node_count` が必要 | 捨てプールを作ってから Spot プールへ |
| 初期ノード数 | `1` | 明示 | `initial_node_count` | デフォルトプール用 |
| Terraform 削除保護 | オフ | 明示 | `deletion_protection = false` | |
| リリースチャネル | `REGULAR` | 明示 | `release_channel.channel` | |
| クラスタ / Services IP | セカンダリ範囲名 | 明示 | `ip_allocation_policy` | |
| Workload Identity | `{project}.svc.id.goog` | 明示 | `workload_identity_config.workload_pool` | |
| ラベル | resource_labels | 明示 | GKE は `labels` ではなく **`resource_labels`** | |

## google_container_node_pool.spot

| 項目 | 本サンプル | Terraform | 備考 |
|---|---|---|---|
| 名前 | `spot-pool` | `name` | |
| ノード数 | `1` | `node_count`（オートスケールなし） | |
| マシン | `e2-medium` | `node_config.machine_type` | |
| Spot | オン | `node_config.spot = true` | 予告なく回収される |
| ディスク | 30 GB / `pd-balanced` | `disk_size_gb` / `disk_type` | |
| スコープ | `cloud-platform` | `oauth_scopes` | GKE ノードの一般的な指定 |
| レガシーメタデータ | 無効 | `metadata.disable-legacy-endpoints = "true"` | 推奨 |
| Workload Identity メタデータ | `GKE_METADATA` | `workload_metadata_config.mode` | |
| 自動修復 / 自動アップグレード | オン | `management.auto_repair` / `auto_upgrade` | |

検証後は必ず destroy してください。GKE は課金が大きくなりやすいです。
