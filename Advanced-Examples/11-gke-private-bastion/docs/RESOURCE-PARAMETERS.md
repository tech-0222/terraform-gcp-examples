# 11 - リソースパラメータ対応

このファイルは**本サンプルのプライベートGKEクラスタと踏み台**について対応づけます。自動生成の`docs/PARAMETER.md`とは別物です。

一次情報:

- [google_container_cluster](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_cluster)
- [Creating a private cluster](https://cloud.google.com/kubernetes-engine/docs/how-to/private-clusters)
- [IAP TCP forwarding](https://cloud.google.com/iap/docs/using-tcp-forwarding)

## 確認コマンド

```bash
gcloud container clusters describe "$(terraform output -raw cluster_name)" \
  --zone="$(terraform output -raw zone)" --format=json
gcloud compute instances describe "$(terraform output -raw bastion_name)" \
  --zone="$(terraform output -raw zone)" --format=json
```

## ネットワーク

| 項目 | 本サンプル | Terraform | 備考 |
|---|---|---|---|
| VPC | `tf-adv-gke-bastion-vpc`、カスタムモード、`REGIONAL` | `auto_create_subnetworks = false` | |
| GKE Subnet | `10.40.0.0/24`、PGAオン | `private_ip_google_access = true` | Pods `10.41.0.0/16`、Services `10.42.0.0/20` |
| 踏み台Subnet | `10.43.0.0/24`、GKEと分離 | 独立したSubnet | `master_authorized_networks`をこのCIDRだけに絞るため |
| Cloud NAT | 両Subnetに適用 | `google_compute_router_nat` | プライベートノードのイメージ取得等に必要。GKE APIはNAT不使用（プライベートエンドポイント） |
| Firewall | IAP SSHのみ、2本（踏み台・GKEノード） | `source_ranges = ["35.235.240.0/20"]` | |

## google_container_cluster.primary

| 項目 | 本サンプル | 区分 | Terraform | 備考 |
|---|---|---|---|---|
| コントロールプレーン | プライベート | 明示 | `private_cluster_config.enable_private_endpoint = true` | VPC内（踏み台Subnet）からのみ到達可 |
| ノード | プライベート | 明示 | `private_cluster_config.enable_private_nodes = true` | 外部IPなし |
| 接続許可元 | 踏み台SubnetのCIDRのみ | 明示 | `master_authorized_networks_config` | 送信元はプライベートIPで判定。NAT外部IPは無関係 |
| Workload Identity | 有効 | 明示 | `workload_identity_config.workload_pool` | Pool設定のみ。Podでの実利用は`03-gke-workload-identity-gcs`を参照 |
| ノードプール | Spot、`e2-small`x1 | 明示 | `node_config.spot = true` | コスト優先。可用性が必要な用途には不向き |
| ノードあたり最大Pod数 | 未指定（GKEデフォルトの110） | `var.max_pods_per_node`（デフォルト`null`） | `default_max_pods_per_node = var.max_pods_per_node` | `null`の場合は属性自体を省略し、既存の動作（デフォルト110）を完全に維持する。作成後変更不可。小さい値を指定して検証する例は`docs/blog`側の「Pod/ServiceのIPレンジ設計」記事を参照 |

未指定（デフォルト）の項目はコンソール/APIのデフォルト値に従う。推測での記載はしない。

## 踏み台（google_compute_instance.bastion）

| 項目 | 本サンプル | Terraform | 備考 |
|---|---|---|---|
| 外部IP | なし | `network_interface`に`access_config`を置かない | IAP経由でのみSSH |
| SA | 専用SA、`roles/container.admin`（プロジェクトレベル） | `google_project_iam_member.bastion_gke` | `container.clusterAdmin`は`nodes.list`を含まないため`kubectl get nodes`がForbiddenになる。フル管理権限の`container.admin`が必要 |
| OS Login | 有効 | `metadata.enable-oslogin = "TRUE"` | IAP SSHには`iap.tunnelResourceAccessor`・`compute.viewer`・`compute.osLogin`が必要（`var.iap_member`に付与） |
| Image | Debian 12 | `debian-cloud/debian-12` | 起動スクリプトで`kubectl`・GKE認証プラグインを`apt`インストール |

## Artifact Registry

| 項目 | 本サンプル | Terraform | 備考 |
|---|---|---|---|
| リポジトリ | `tf-adv-gke-bastion-repo`、Docker形式 | `google_artifact_registry_repository` | |
| ノードSAの権限 | `roles/artifactregistry.reader`のみ | `google_artifact_registry_repository_iam_member` | イメージpullはkubeletがノードSAで実行。pushは開発者側が別途行う（本サンプルはローカルからdocker push） |
