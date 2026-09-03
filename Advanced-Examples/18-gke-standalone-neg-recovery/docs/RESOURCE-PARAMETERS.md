# 18 - リソースパラメータ対応

このファイルは**スタンドアロンNEGと外部Application LBの関係**について対応づけます。自動生成の`docs/PARAMETER.md`とは別物です。VPC/踏み台/GKEの基本部分は`11-gke-private-bastion`と同じ構成のため、ここでは差分とNEG周りを中心に記載します。

一次情報:

- [Google Cloud: Container-native load balancing through standalone zonal NEGs](https://cloud.google.com/kubernetes-engine/docs/how-to/standalone-neg)
- [Google Cloud: Zonal NEGs overview](https://cloud.google.com/load-balancing/docs/negs/zonal-neg-concepts)
- [google_compute_backend_service](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_backend_service)
- [google_compute_network_endpoint_group（data source）](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_network_endpoint_group)

## 確認コマンド

```bash
gcloud compute network-endpoint-groups list --filter="name=$(terraform output -raw neg_name)"
gcloud compute network-endpoint-groups list-network-endpoints "$(terraform output -raw neg_name)" --zone=asia-northeast1-a
gcloud compute backend-services describe "$(terraform output -raw backend_service_name)" --global
gcloud compute backend-services get-health "$(terraform output -raw backend_service_name)" --global
kubectl describe svc neg-app-svc
```

## ネットワーク（VPC/踏み台）

`11-gke-private-bastion`と同じ。CIDRのみ再掲する。

| 項目 | 本サンプル |
|---|---|
| GKE Subnet | `10.40.0.0/24`（Pods `10.41.0.0/16`、Services `10.42.0.0/20`） |
| 踏み台Subnet | `10.43.0.0/24` |
| GKEコントロールプレーン | `172.16.4.0/28` |

## google_container_cluster.primary（11との差分）

| 項目 | 本サンプル | 区分 | Terraform | 備考 |
|---|---|---|---|---|
| ロケーション種別 | リージョナル | 明示 | `location = var.region` | `11`はゾーナル。NEGはゾーンごとに作られるため、複数ゾーンにしないと「複数NEGを束ねたバックエンド」にならない |
| ノード配置 | 2ゾーンにゾーンごと1台 | 明示 | `node_locations = var.gke_zones`、`node_count = 1` | `node_count`はゾーンごとの値 |

## スタンドアロンNEG（Terraform管理外）

| 項目 | 本サンプル | 備考 |
|---|---|---|
| 作成主体 | **GKEのNEGコントローラ** | `Service`の`cloud.google.com/neg`アノテーションから作られる。Terraformは作成しない |
| 名前 | `tf-adv-negrec-neg` | アノテーションの`name`と`var.neg_name`が一致している必要がある |
| 作られる数 | クラスタが持つゾーンの数だけ | 本サンプルは2ゾーンなので2つ |
| Terraformからの参照 | `data`ソース | `data.google_compute_network_endpoint_group`。**plan時に解決されるため、NEGが無ければplanが失敗する** |
| 削除 | Serviceを消すとGKEが削除する | ただし**バックエンドから参照されている間は削除できない**（GCPが拒否する） |

### `14`（Internal LB）との参照方法の違い

| 項目 | 14-gke-bastion-ilb-multi-neg | 18（本サンプル） |
|---|---|---|
| NEGの参照 | URL文字列を組み立て | `data`ソース |
| NEG不在時のエラー | **apply時**にAPIが404を返す | **plan時**に`not found`で失敗 |

どちらも「NEGが先に存在している必要がある」点は同じですが、失敗するタイミングが異なります。

## google_compute_backend_service.lb

| 項目 | 本サンプル | 区分 | Terraform | 備考 |
|---|---|---|---|---|
| スキーム | `EXTERNAL` | 明示 | `load_balancing_scheme` | グローバル外部Application LB |
| バックエンド | ゾーンごとのNEG | 明示 | `dynamic "backend"`（`for_each = var.gke_zones`） | `group`に`data`ソースのIDを渡す |
| 分散モード | `RATE`、`max_rate_per_endpoint = 100` | 明示 | `balancing_mode` | NEGバックエンドでは`RATE`が必要（`UTILIZATION`は不可） |
| ヘルスチェック | `USE_SERVING_PORT` | 明示 | `google_compute_health_check.lb` | エンドポイントがPodのため、NEGの提供ポートに追従させる |

**NEGが削除・再作成されても、この`backends[]`は自動では復元されません。** `terraform apply`（または`gcloud compute backend-services add-backend`）による再付与が必要です。これが本サンプルの主要な検証結果です。

## ファイアウォール

| 項目 | 本サンプル | 区分 | Terraform | 備考 |
|---|---|---|---|---|
| ヘルスチェック許可 | `130.211.0.0/22`、`35.191.0.0/16` → tcp/80 | 明示 | `google_compute_firewall.allow_lb_health_check` | コンテナネイティブLBはPod IPへ直接通信するため、これがないとバックエンドがHEALTHYにならない |

未指定（デフォルト）の項目はコンソール/APIのデフォルト値に従う。推測での記載はしない。
