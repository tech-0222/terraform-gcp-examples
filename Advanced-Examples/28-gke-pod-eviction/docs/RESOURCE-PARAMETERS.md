# リソースのパラメータ対応

コンソール / API の項目と、Terraform の属性の対応。

## GKE: 監視の有効化

| コンソール | Terraform | 備考 |
|---|---|---|
| 監視 > システム コンポーネント | `monitoring_config.enable_components = ["SYSTEM_COMPONENTS"]` | |
| 監視 > kube state metrics | `enable_components` に `POD` / `DAEMONSET` / `DEPLOYMENT` / `STATEFULSET` / `STORAGE` / `HPA` | 種類ごとに個別指定 |
| 監視 > cAdvisor / kubelet | `enable_components` に `CADVISOR` / `KUBELET` | **GKE 1.29.3-gke.1093000 以降のみ** |
| Managed Service for Prometheus | `monitoring_config.managed_prometheus.enabled` | |

**`up=1` でも系列が全部来るわけではない。** マネージド収集は許可リスト方式で、`kube_pod_status_reason` や `kube_node_status_condition` は来ない。

## GKE: 退避に関わるノード設定

| 項目 | 設定場所 | 既定値（実測） |
|---|---|---|
| 退避しきい値 | kubelet（Terraform からは触れない） | `memory.available=100Mi` `nodefs.available=10%` `nodefs.inodesFree=5%` `pid.available=10%` |
| 逼迫解除の待ち時間 | 同上 | `5m0s` |
| kube 予約 | 同上（マシンタイプで決まる） | e2-standard-2 で `cpu=70m` `memory=1819Mi` `ephemeral-storage=15Gi` |

**GKE では退避しきい値を Terraform から変更できない。** ノード設定をカスタムしたい場合は `node_config.kubelet_config` を使うが、退避関連の項目は対象外。

## GKE: 観測の邪魔になる設定

| 項目 | Terraform | 検証時の値 |
|---|---|---|
| ノード自動修復 | `management.auto_repair` | **false**。逼迫中にノードが入れ替わる |
| ノード自動アップグレード | `management.auto_upgrade` | **false** |

## コントロールプレーンへの接続

| コンソール | Terraform | 備考 |
|---|---|---|
| プライベート ノード | `private_cluster_config.enable_private_nodes` | ノードに外部 IP を付けない |
| プライベート エンドポイント | `private_cluster_config.enable_private_endpoint` | **false** にすると踏み台なしで kubectl できる |
| 承認済みネットワーク | `master_authorized_networks_config.cidr_blocks` | **IPv4 のみ。** IPv6 を渡すと plan で落ちる |

## Pod 側（Kubernetes マニフェスト）

| 概念 | マニフェスト | 退避への影響 |
|---|---|---|
| QoS: BestEffort | `resources` を書かない | requests が 0 なので、少しでも使えば「超過」 |
| QoS: Burstable | `requests` のみ | requests 超過量で順位が決まる |
| QoS: Guaranteed | `requests` == `limits` | 超過しないため候補になりにくい |
| Pod 単位のディスク上限 | `limits.ephemeral-storage` | 超えるとノード逼迫と無関係に退避される |
