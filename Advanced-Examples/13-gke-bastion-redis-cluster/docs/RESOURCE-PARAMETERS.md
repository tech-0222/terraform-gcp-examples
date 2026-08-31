# 13 - リソースパラメータ対応

このファイルは**本サンプルのプライベートGKEクラスタ・踏み台・Memorystore for Redis Cluster**について対応づけます。自動生成の`docs/PARAMETER.md`とは別物です。VPC/踏み台/GKEの基本部分は`11-gke-private-bastion`と同じ構成のため、ここではRedis Cluster（PSC）部分を中心に記載します。

一次情報:

- [google_container_cluster](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_cluster)
- [google_redis_cluster](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/redis_cluster)
- [google_network_connectivity_service_connection_policy](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/network_connectivity_service_connection_policy)
- [Memorystore for Redis Cluster: Networking](https://cloud.google.com/memorystore/docs/cluster/networking)
- [Configure Private Service Connect for Memorystore](https://cloud.google.com/memorystore/docs/cluster/about-service-connection-policies)

## 確認コマンド

```bash
gcloud container clusters describe "$(terraform output -raw cluster_name)" \
  --zone="$(terraform output -raw zone)" --format=json
gcloud redis clusters describe "$(terraform output -raw cluster_name)-rediscl" \
  --region="$(terraform output -raw region)" --format=json
gcloud network-connectivity service-connection-policies list \
  --region="$(terraform output -raw region)"
```

## ネットワーク（VPC/踏み台/GKE）

`11-gke-private-bastion`と同じ。詳細はそちらの`docs/RESOURCE-PARAMETERS.md`を参照。CIDRのみ再掲する。

| 項目 | 本サンプル |
|---|---|
| GKE Subnet | `10.40.0.0/24`（Pods `10.41.0.0/16`、Services `10.42.0.0/20`） |
| 踏み台Subnet | `10.43.0.0/24` |
| GKEコントロールプレーン | `172.16.4.0/28` |
| Redis PSC Subnet | `10.44.0.0/29` |

## Private Service Connect（Redis Cluster用）

PSAとは異なり、専用Subnetと`ServiceConnectionPolicy`の両方が必要になる。

| 項目 | 本サンプル | 区分 | Terraform | 備考 |
|---|---|---|---|---|
| PSCエンドポイント用Subnet | `/29`（8アドレス） | 明示 | `google_compute_subnetwork.redis_psc` | 推奨最小サイズ。GKE Subnet・コントロールプレーンCIDRと重複しないこと |
| Service Connection Policy | `service_class = "gcp-memorystore-redis"` | 明示 | `google_network_connectivity_service_connection_policy.redis_psc` | このPolicyがVPC上でどのSubnetをMemorystoreのPSCエンドポイントに使うかを定義する |
| 有効化API | `networkconnectivity.googleapis.com`、`serviceconsumermanagement.googleapis.com` | 明示 | `google_project_service.networkconnectivity` / `.serviceconsumermanagement` | PSC/Service Connection Policy利用に必要 |

## google_redis_cluster.cache

| 項目 | 本サンプル | 区分 | Terraform | 備考 |
|---|---|---|---|---|
| シャード数 | 1 | 明示 | `shard_count = var.redis_shard_count` | 学習用最小構成 |
| レプリカ数 | 0（レプリカなし、HAなし） | 明示 | `replica_count = var.redis_replica_count` | PoC時点のデフォルトは1だったが、本サンプルではコスト最小化のため0に変更。可用性が必要なら1以上を指定 |
| ノードタイプ | `REDIS_SHARED_CORE_NANO` | 明示 | `node_type = var.redis_node_type` | Redis Clusterで選択可能な最小ノードタイプ |
| ゾーン分散 | `MULTI_ZONE` | 明示 | `zone_distribution_config.mode` | 単一ゾーン障害に対する耐性のための設定（レプリカ0でもノード配置には影響する） |
| 接続方式 | PSC | 明示 | `psc_configs { network = ... }` | `discovery_endpoints`が接続先として払い出される |
| 転送暗号化 | 無効 | 明示 | `transit_encryption_mode = "TRANSIT_ENCRYPTION_MODE_DISABLED"` | 検証用途のため無効化。本番では有効化を検討 |
| 認証 | 無効 | 明示 | `authorization_mode = "AUTH_MODE_DISABLED"` | 検証用途のため無効化。本番ではAUTH有効化を検討 |
| Region | GKEと同じ`asia-northeast1` | 明示 | `region = var.region` | Redis Clusterはリージョナルリソース |

## 接続先（discovery_endpoints）

Redis Instanceの`host`/`port`と異なり、Redis Clusterは`discovery_endpoints`（配列）でエンドポイントを払い出す。クライアントはcluster mode（`redis-cli -c`）で接続し、実際のデータはシャードごとに異なるノードへリダイレクト（`MOVED`）される。

| 項目 | 本サンプル | 区分 | Terraform | 備考 |
|---|---|---|---|---|
| Discovery Endpoint | `discovery_endpoints[0].address` / `.port` | 明示 | `try(google_redis_cluster.cache.discovery_endpoints[0].address, null)` | クライアントはこのエンドポイントに接続後、cluster modeでリダイレクトに追従する |

未指定（デフォルト）の項目はコンソール/APIのデフォルト値に従う。推測での記載はしない。
