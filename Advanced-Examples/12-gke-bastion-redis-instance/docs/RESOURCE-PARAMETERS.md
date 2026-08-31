# 12 - リソースパラメータ対応

このファイルは**本サンプルのプライベートGKEクラスタ・踏み台・Memorystore for Redis**について対応づけます。自動生成の`docs/PARAMETER.md`とは別物です。VPC/踏み台/GKEの基本部分は`11-gke-private-bastion`と同じ構成のため、ここではRedis部分を中心に記載します。

一次情報:

- [google_container_cluster](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_cluster)
- [google_redis_instance](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/redis_instance)
- [Memorystore for Redis: Networking](https://cloud.google.com/memorystore/docs/redis/networking)
- [Configure Private Service Access](https://cloud.google.com/vpc/docs/configure-private-services-access)

## 確認コマンド

```bash
gcloud container clusters describe "$(terraform output -raw cluster_name)" \
  --zone="$(terraform output -raw zone)" --format=json
gcloud redis instances describe "$(terraform output -raw cluster_name)-redis" \
  --region="$(terraform output -raw region)" --format=json
```

## ネットワーク（VPC/踏み台/GKE）

`11-gke-private-bastion`と同じ。詳細はそちらの`docs/RESOURCE-PARAMETERS.md`を参照。CIDRのみ再掲する。

| 項目 | 本サンプル |
|---|---|
| GKE Subnet | `10.40.0.0/24`（Pods `10.41.0.0/16`、Services `10.42.0.0/20`） |
| 踏み台Subnet | `10.43.0.0/24` |
| GKEコントロールプレーン | `172.16.4.0/28` |

## Private Service Access（Redis用）

| 項目 | 本サンプル | 区分 | Terraform | 備考 |
|---|---|---|---|---|
| Peering Range | `/24`、`INTERNAL`、`VPC_PEERING` | 明示 | `google_compute_global_address.redis_psa_range` | GKE Subnet・コントロールプレーンCIDRと重複しないサイズを確保 |
| VPC Peering | `servicenetworking.googleapis.com`との接続 | 明示 | `google_service_networking_connection.redis_psa` | この接続がないとRedis Instance作成時にエラーになる |

## google_redis_instance.cache

| 項目 | 本サンプル | 区分 | Terraform | 備考 |
|---|---|---|---|---|
| Tier | `BASIC`（レプリカなし） | 明示 | `tier = "BASIC"` | 可用性が必要なら`STANDARD_HA`を検討 |
| メモリサイズ | 1GB | 明示 | `memory_size_gb = var.redis_memory_size_gb` | `BASIC`は1〜300GBの範囲で指定可能 |
| 接続先VPC | GKE用VPC | 明示 | `authorized_network` | 同一VPC内であればFirewall設定なしで到達可能（PSAの仕組み） |
| Region | GKEと同じ`asia-northeast1` | 明示 | `region = var.region` | Redisはリージョナルリソース。ゾーンは自動選択 |

未指定（デフォルト）の項目はコンソール/APIのデフォルト値に従う。推測での記載はしない。
