# 07 - GKE クラスタ / ノードプール パラメータ対応

このファイルは **本サンプルの Standard GKE**（`google_container_cluster.primary` + `google_container_node_pool.spot`）について、コンソール項目・`gcloud --format=json`・Terraform 属性を対応づけます。

自動生成の `docs/PARAMETER.md`（terraform-docs）とは別物です。手で編集してよい参照資料です。

コンソール項目の切り口は Obsidian の GKE Parameter カタログ（クラスタ設定 / ノードプール設定）に合わせています。**値は本サンプルのコード**です。別 PoC のリージョナル・プライベートクラスタ（Dataplane V2、Cloud DNS、max pods 32、専用ノード SA など）の実測値は使いません。

記載は次の一次情報に合わせています。

- [google_container_cluster](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_cluster)
- [google_container_node_pool](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_node_pool)
- [REST Cluster](https://cloud.google.com/kubernetes-engine/docs/reference/rest/v1/projects.locations.clusters)
- [Choose a cluster mode](https://cloud.google.com/kubernetes-engine/docs/concepts/choose-cluster-mode)
- [Release channels](https://cloud.google.com/kubernetes-engine/docs/concepts/release-channels)
- [VPC-native clusters](https://cloud.google.com/kubernetes-engine/docs/concepts/alias-ips)
- [Private clusters](https://cloud.google.com/kubernetes-engine/docs/how-to/private-clusters)
- [Flexible Pod CIDR](https://cloud.google.com/kubernetes-engine/docs/how-to/flexible-pod-cidr)
- [Dataplane V2](https://cloud.google.com/kubernetes-engine/docs/concepts/dataplane-v2)
- [Workload Identity](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity)
- [Spot VMs on GKE](https://cloud.google.com/kubernetes-engine/docs/concepts/spot-vms)
- [Shielded GKE nodes](https://cloud.google.com/kubernetes-engine/docs/how-to/shielded-gke-nodes)

## 凡例

| 記号 | 意味 |
|---|---|
| **明示** | `main.tf` / `network.tf` / 変数で指定している |
| **未指定** | コードに書いておらず、GKE / Provider のデフォルトに任せる |
| **出力** | apply 後に API が割り当てる値 |
| **クラスタ再作成 ○** | 変更するとクラスタの replace になりやすい |
| **プール再作成 ○** | 変更するとノードプール（ノード）の recreate になりやすい |
| **再作成 −** | 既存クラスタ / プールを更新できることが多い |

値はデフォルト変数（`terraform.tfvars.example`）を前提にしています。`cluster_name` や `machine_type` を上書きした場合は読み替えてください。

最終判断は常に `terraform plan` です。Provider が ForceNew とする代表例はクラスタの `name` / `location` / `network` / `subnetwork` / `enable_autopilot` / `datapath_provider`、および IP エイリアス範囲です。ノードのマシンタイプ・Spot・イメージ種類は **ノードプール側** の recreate です。

## 確認コマンド

```bash
gcloud container clusters describe "$(terraform output -raw cluster_name)" \
  --zone="$(terraform output -raw cluster_location)" \
  --format=json
```

`gcloud` の対象 Project は ADC / `gcloud config` 側で合わせます。JSON パスは REST Cluster / NodePool に合わせています。

---

# クラスタ設定

## 基本

| 項目 | 本サンプル | 区分 | 再作成 | Terraform | gcloud パス |
|---|---|---|---|---|---|
| 名前 | `tf-example-gke`（`var.cluster_name`） | 明示 | クラスタ ○ | `name` | `name` |
| モード | Standard | 未指定 | クラスタ ○ | `enable_autopilot` 未指定（既定 `false`） | Autopilot なら `autopilot.enabled` |
| Autopilot コンピューティング クラスの互換性 | 使わない | 未指定 | − | Autopilot 向け。本サンプルは Standard | |
| ロケーション タイプ | **ゾーナル** | 明示 | クラスタ ○ | `location` にゾーンを指定 | `location` がゾーンなら zonal |
| ゾーン | `asia-northeast1-a`（`var.zone`） | 明示 | クラスタ ○ | `location` | `location` / `zone` |
| デフォルトのノードゾーン | クラスタゾーンと同じ（追加ゾーンなし） | 未指定 | クラスタ ○ になりやすい | `node_locations` 未指定 | `locations[]` |
| 合計サイズ | Spot プール **1**（デフォルトプールは作成直後削除） | 明示 | −（プールサイズ） | クラスタ `initial_node_count = 1`（捨てプール）+ プール `node_count` | `currentNodeCount` 等 |
| リリース チャンネル | Regular | 明示 | − | `release_channel.channel = "REGULAR"` | `releaseChannel.channel` |
| バージョン | ピン留めしない。チャンネルの既定 | 未指定 | − | `min_master_version` 未指定 | `currentMasterVersion`（Output） |
| COS / サポート期限 | バージョン連動 | 出力 | − | 直接指定しない | ノードの `config.imageType` / リリースノート |
| ロールアウト シーケンス / フリート | 未登録 | 未指定 | − | `fleet` 未指定 | `fleet` |

`remove_default_node_pool = true` のため、クラスタ作成時のデフォルトプールは捨てます。実ノードは `google_container_node_pool.spot` です。

## アップグレード / 自動化

| 項目 | 本サンプル | 区分 | 再作成 | Terraform | 備考 |
|---|---|---|---|---|---|
| コントロールプレーン自動アップグレード | Regular チャンネルに任せる | 未指定 | − | `release_channel`。一時停止はコンソール / API の upgrade pause | |
| メンテナンスの時間枠 / 除外 | 指定なし | 未指定 | − | `maintenance_policy` | |
| Pub/Sub アップグレード通知 | 無効（未設定） | 未指定 | − | `notification_config` | |
| 垂直 Pod 自動スケーリング | 無効 | 未指定 | − | `vertical_pod_autoscaling` | Provider: ブロック未指定なら無効 |
| ノードの自動プロビジョニング (NAP) | 無効 | 未指定 | − | `cluster_autoscaling` | |
| 自動スケーリング プロファイル | 未使用（NAP なし） | 未指定 | − | NAP 時の既定は `BALANCED` | |

## コントロール プレーン ネットワーキング

本サンプルは **公開クラスタ** です。`private_cluster_config` は書きません（Provider: `enable_private_nodes` が true でないならブロックごと省略が推奨）。

| 項目 | 本サンプル | 区分 | 再作成 | Terraform | gcloud パス |
|---|---|---|---|---|---|
| DNS エンドポイント | 未設定（IP エンドポイント既定） | 未指定 | − | `control_plane_endpoints_config.dns_endpoint_config` | |
| パブリック エンドポイント | 有効 | 未指定 | − | `enable_private_endpoint` を使わない | `privateClusterConfig.publicEndpoint` または `endpoint` |
| プライベート エンドポイント専用 | 使わない | 未指定 | クラスタ ○ になりやすい | `private_cluster_config.enable_private_endpoint` | `privateClusterConfig.enablePrivateEndpoint` |
| コントロールプレーン専用 CIDR | なし | 未指定 | クラスタ ○ | `master_ipv4_cidr_block`（プライベート時 /28） | `privateClusterConfig.masterIpv4CidrBlock` |
| 他リージョンからの内部アクセス | 未設定 | 未指定 | − | `master_global_access_config` | |
| 承認済みネットワーク | 無効（制限しない） | 未指定 | − | `master_authorized_networks_config` 省略 | `masterAuthorizedNetworksConfig` |
| GCP 外部 IP を承認済みに含める | 該当なし | 未指定 | − | `gcp_public_cidrs_access_enabled` | |

公開エンドポイントがあるため、IAM と認証さえあればインターネットから API に届きます。学習用の最小構成であり、本番のネットワーク分離ではありません。

## クラスタ ネットワーキング

VPC / Subnet / セカンダリ CIDR の値は **[RESOURCE-PARAMETERS.md](./RESOURCE-PARAMETERS.md)** が正本です。ここではクラスタがそれらをどう参照するかと、クラスタ専用のネットワーク機能だけ書きます。

| 項目 | 本サンプル | 区分 | 再作成 | Terraform | gcloud パス |
|---|---|---|---|---|---|
| ネットワーク / サブネット | RESOURCE-PARAMETERS の VPC / Subnet を参照 | 明示 | クラスタ ○ | `network` / `subnetwork`（名前参照。CIDR は Subnet 側） | `network` / `subnetwork` |
| 自動 IPAM | 使わない | 明示 | クラスタ ○ | `ip_allocation_policy` に範囲**名** | `ipAllocationPolicy.useIpAliases` |
| VPC ネイティブ | 有効 | 明示 | クラスタ ○ | `cluster_secondary_range_name = "pods"`、`services_secondary_range_name = "services"`。新規クラスタの `networking_mode` 既定は `VPC_NATIVE` | `ipAllocationPolicy` |
| デフォルト SNAT | 有効のまま | 未指定 | − | `default_snat_status` 未指定 | `defaultSnatStatus` |
| マルチサブネット | なし | 未指定 | クラスタ ○ | 追加 subnet なし | |
| スタックタイプ | IPv4 | 未指定 | クラスタ ○ | `ip_allocation_policy.stack_type` 未指定 | |
| プライベート CP エンドポイント用サブネット | なし | 未指定 | クラスタ ○ | `private_endpoint_subnetwork` | |
| 追加 Pod 範囲 / マルチサブネット Pod 範囲 | なし | 未指定 | − | | |
| ノードあたりの最大ポッド数 | **未指定 → VPC-native 既定 110** | 未指定 | クラスタ ○（クラスタ既定） | `default_max_pods_per_node`。プールは `max_pods_per_node` | `defaultMaxPodsConstraint` |
| ネットワーク サービス ティア | Default | 未指定 | − | | |
| ノード内の可視化 | 無効 | 未指定 | − | `enable_intranode_visibility` | `networkConfig.enableIntraNodeVisibility` |
| HTTP ロード バランシング | 有効（GKE 既定） | 未指定 | − | `addons_config.http_load_balancing`。未指定時 enabled | |
| L4 ILB サブセット化 | 無効 | 未指定 | − | `enable_l4_ilb_subsetting` | |
| Calico ネットワーク ポリシー | 無効 | 未指定 | クラスタ ○ になりやすい | `network_policy` / `addons_config.network_policy_config` 既定 disabled | |
| Dataplane V2 | **無効**（レガシー datapath） | 未指定 | クラスタ ○ | `datapath_provider` 未指定。Provider 既定 `LEGACY_DATAPATH`。V2 は `ADVANCED_DATAPATH` | `networkConfig.datapathProvider` |
| Dataplane V2 指標 / オブザーバビリティ | 該当なし | 未指定 | − | `monitoring_config.advanced_datapath_observability_config` | |
| DNS プロバイダ | kube-dns（プラットフォーム既定） | 未指定 | クラスタ ○ になりやすい | `dns_config` 未指定。`cluster_dns` 既定は `PROVIDER_UNSPECIFIED` | `dnsConfig` |
| NodeLocal DNSCache | 無効 | 未指定 | クラスタ ○ になりやすい | `addons_config.dns_cache_config` 既定 disabled | |
| Gateway API | 無効 | 未指定 | クラスタ ○ になりやすい | `gateway_api_config` | |
| マルチネットワーキング | 無効 | 未指定 | クラスタ ○ | `enable_multi_networking` | |
| ノード間の透過的暗号化 | 無効 | 未指定 | クラスタ ○ | `in_transit_encryption_config` 等 | |
| FQDN ネットワーク ポリシー | 無効 | 未指定 | クラスタ ○ | `enable_fqdn_network_policy` | |
| LB Service の VPC FW 自動作成 | 有効のまま | 未指定 | − | `disable_l4_lb_firewall_reconciliation` 未指定 | |

## 新しいデフォルトのノードプール構成

| 項目 | 本サンプル | 区分 | Terraform |
|---|---|---|---|
| プライベート ノード | **無効**（ノードに外部 IP が付く） | 未指定 | `private_cluster_config.enable_private_nodes` およびプールの `network_config.enable_private_nodes` 未指定 |

Cloud NAT は作りません。ノードは外部 IP 経由でインターネットに出られます（学習用）。本番のプライベートノード構成ではありません。

## セキュリティ

| 項目 | 本サンプル | 区分 | 再作成 | Terraform | 備考 |
|---|---|---|---|---|---|
| バイナリ承認 | 無効 | 未指定 | クラスタ ○ になりやすい | `binary_authorization` | |
| Secret Manager アドオン | 無効 | 未指定 | − | `secret_manager_config` | 有効時のローテーション間隔既定は 2 分（Provider） |
| シールドされた GKE ノード | **有効**（Provider 既定） | 未指定 | − | `enable_shielded_nodes` 既定 `true` | |
| Confidential GKE Node | 無効 | 未指定 | クラスタ / プール ○ | `confidential_nodes` | |
| アプリ層 Secret 暗号化 | 無効（DECRYPTED） | 未指定 | − | `database_encryption` | |
| Workload Identity | 有効 | 明示 | −（現行は後から有効化可。計画は plan で確認） | `workload_identity_config.workload_pool` | |
| WI の名前空間（プール） | `{project_id}.svc.id.goog` | 明示 | − | 同上 | `workloadIdentityConfig.workloadPool` |
| RBAC 向け Google グループ | 無効 | 未指定 | − | `authenticator_groups_config` | |
| 以前の承認 (legacy ABAC) | 無効 | 未指定 | − | `enable_legacy_abac` 既定 `false` | |
| 基本認証 | 無効（現行 GKE では不可） | − | − | 属性なし | |
| クライアント証明書 | 発行しない（現行既定） | 未指定 | − | `master_auth.client_certificate_config` | |
| Security posture | コード未指定。コンソールは BASIC 相当が出ることが多い | 未指定 | − | `security_posture_config` | 実値は describe |
| ワークロード脆弱性スキャン | 未指定 | 未指定 | − | `vulnerability_mode` | |

## メタデータ・特徴量

| 項目 | 本サンプル | 区分 | 再作成 | Terraform |
|---|---|---|---|---|
| 説明 | なし | 未指定 | − | `description` |
| ラベル | 下記 `resource_labels` | 明示 | − | GKE クラスタは **`resource_labels`**（`labels` ではない） |
| Resource Manager タグ | なし | 未指定 | − | `resource_manager_tags` |
| Ray Operator | 無効 | 未指定 | クラスタ ○ | `addons_config.ray_operator_config` 既定 disabled |
| ロギング | コード未指定。GKE 既定は SYSTEM + WORKLOADS | 未指定 | − | `logging_config.enable_components` |
| Cloud Monitoring | コード未指定。システム指標は既定で収集 | 未指定 | − | `monitoring_config` |
| マネージド OpenTelemetry | 無効 | 未指定 | − | |
| Managed Service for Prometheus | コード未指定 | 未指定 | − | `monitoring_config.managed_prometheus`。実値は describe |
| 自動アプリケーション モニタリング | 未指定 | 未指定 | − | `auto_monitoring_config` |
| Kubernetes アルファ機能 | 無効 | 未指定 | クラスタ ○ | `enable_kubernetes_alpha` / `enable_k8s_beta_apis` |
| 費用の割り当て / 使用状況測定 | 無効 | 未指定 | − | `cost_management_config` / `resource_usage_export_config` |
| Backup for GKE | 無効 | 未指定 | − | `addons_config.gke_backup_agent_config` 既定 disabled |
| コネクタ | 無効 | 未指定 | − | `addons_config.config_connector_config` |
| GCE PD CSI | 有効（新規クラスタ既定） | 未指定 | クラスタ ○ になりやすい | `addons_config.gce_persistent_disk_csi_driver_config` |
| イメージ ストリーミング | 無効 | 未指定 | − | ノードの `gcfs_config` |
| Filestore CSI | 無効 | 未指定 | クラスタ ○ | `gcp_filestore_csi_driver_config` 既定 disabled |
| GCS FUSE CSI | 無効（Standard 既定） | 未指定 | クラスタ ○ | `gcs_fuse_csi_driver_config` |
| Lustre CSI | 無効 | 未指定 | クラスタ ○ | `lustre_csi_driver_config` |
| サービス メッシュ | 無効 | 未指定 | クラスタ ○ | Istio / Cloud Service Mesh アドオン未指定 |
| Terraform 削除保護 | オフ | 明示 | − | `deletion_protection = false`。Provider 5.x+ では **false を state に書かないと destroy できない** |

本サンプルのクラスタ `resource_labels`:

```hcl
env        = "test"
system     = "tf-examples"
component  = "gke"
managed_by = "terraform"
example    = "07-gke"
```

google provider 6.x 以降は attribution ラベル（`goog-terraform-provisioned=true`）が付くことがあります。

---

# ノードプール設定（spot-pool）

## 基本

| 項目 | 本サンプル | 区分 | 再作成 | Terraform | gcloud パス |
|---|---|---|---|---|---|
| クラスタ | `tf-example-gke` | 明示 | − | `cluster` | `cluster` |
| プール名 | `spot-pool` | 明示 | プール ○ | `name` | `name` |
| ノードのバージョン | クラスタ / 自動アップグレードに連動 | 未指定 | − | `version` 未指定。`auto_upgrade = true` と併用しない | `version` |
| COS バージョン / サポート期限 | バージョン連動 | 出力 | − | | |

## サイズ

| 項目 | 本サンプル | 区分 | 再作成 | Terraform |
|---|---|---|---|---|
| ノード数 | 1（ゾーナルなので合計 1） | 明示 | − | `node_count`。`autoscaling` と併用しない |
| 自動スケーリング | オフ | 未指定 | − | `autoscaling` 省略 |
| ノードゾーン | `asia-northeast1-a` | 明示（プール `location`） | プール ○ | `location` / `node_locations` 未指定ならクラスタに従う |

## ノード

| 項目 | 本サンプル | 区分 | 再作成 | Terraform | 備考 |
|---|---|---|---|---|---|
| イメージの種類 | COS_CONTAINERD（GKE 既定） | 未指定 | プール ○ | `node_config.image_type` | |
| マシンタイプ | `e2-medium` | 明示 | プール ○ | `node_config.machine_type` | |
| GPU | なし | 未指定 | プール ○ | `guest_accelerator` | |
| ブートディスクの種類 | `pd-balanced` | 明示 | プール ○ | `disk_type`。未指定時はマシンにより `pd-balanced` または `hyperdisk-balanced` | |
| ブートディスクサイズ | 30 GB | 明示 | − のことが多い | `disk_size_gb`。未指定既定 **100 GB** | |
| ブートディスク暗号化 | Google 管理 | 未指定 | プール ○ | CMEK 未指定 | |
| 一時ローカル SSD | 0 | 未指定 | プール ○ | `local_ssd_count` | |
| 予約 | なし | 未指定 | − | `reservation_affinity` | |
| プロビジョニング モデル | **Spot** | 明示 | プール ○ | `node_config.spot = true`。`preemptible` とは別フラグ。両方の既定は `false` | |
| ネストされた仮想化 | 無効 | 未指定 | プール ○ | | |
| コンパクト プレースメント | 無効 | 未指定 | プール ○ | `placement_policy` | |
| DWS キュー | 無効 | 未指定 | − | `queued_provisioning` | |
| イメージ ストリーミング | 無効 | 未指定 | − | `gcfs_config` | |

## ネットワーク / Pod IP

| 項目 | 本サンプル | 区分 | 再作成 | Terraform |
|---|---|---|---|---|
| プライベート ノード | 無効（クラスタ継承） | 未指定 | − | `network_config.enable_private_nodes` |
| VPC / Subnet | クラスタと同じ | − | プール ○ | クラスタ継承 |
| Pod 範囲の上書き | なし（クラスタの `pods`） | 未指定 | プール ○ | `max_pods_per_node` / `network_config.pod_range` 未指定 → 既定 110 |

## 自動化 / アップグレード

| 項目 | 本サンプル | 区分 | 再作成 | Terraform | 備考 |
|---|---|---|---|---|---|
| 自動アップグレード | オン | 明示 | − | `management.auto_upgrade = true`。未指定でも Provider 既定は有効 | |
| 自動修復 | オン | 明示 | − | `management.auto_repair = true`。未指定でも既定有効 | |
| アップグレード戦略 | サージ（GKE 既定） | 未指定 | − | `upgrade_settings`。既定は max surge 1 / max unavailable 0 が多い | 実値は describe |

## セキュリティ / メタデータ

| 項目 | 本サンプル | 区分 | 再作成 | Terraform | 備考 |
|---|---|---|---|---|---|
| Sandbox (gVisor) | 無効 | 未指定 | プール ○ | `sandbox_config` | |
| サービス アカウント | **デフォルト Compute Engine SA** | 未指定 | プール ○ | `node_config.service_account` 省略 | 専用 SA は作らない |
| OAuth スコープ | `cloud-platform` | 明示 | プール ○ | `oauth_scopes` | 専用 SA + IAM 絞り込みが推奨。本サンプルは学習用にスコープのみ広い |
| GKE メタデータ サーバー | `GKE_METADATA` | 明示 | − | `workload_metadata_config.mode`。クラスタ WI 必須 | |
| セキュアブート | コード未指定。ノード Shielded 既定は **オフ** | 未指定 | プール ○ | `shielded_instance_config.enable_secure_boot` 既定 `false` | |
| 整合性モニタリング | コード未指定。既定 **オン** | 未指定 | − | `enable_integrity_monitoring` 既定 `true` | |
| Kubernetes ラベル | `env` ほか下記（GCE ノードラベルでもある） | 明示 | − | `node_config.labels` | GKE が `cluster_name` / `node_pool` を足すことがある |
| ネットワーク タグ | コード未指定。GKE が `gke-...` を自動付与 | 出力 | − | `tags` 未指定 | |
| GCE メタデータ | `disable-legacy-endpoints=true` | 明示 | − | `node_config.metadata` | WI 利用時の推奨 |

ノードに明示しているラベル:

```hcl
env        = "test"
system     = "tf-examples"
component  = "gke"
managed_by = "terraform"
example    = "07-gke"
```

---

## コードで触っていない主な項目

次は意図的にデフォルトのままです。コンソールや JSON には値が出ることがあります。

- Autopilot / リージョナル / プライベートノード / 承認済みネットワーク
- Dataplane V2 / Cloud DNS / NodeLocal DNSCache / Gateway API
- max pods の縮小、ノード内可視化
- Secret Manager アドオン、Filestore / GCS FUSE CSI
- NAP、VPA、メンテナンスウィンドウ
- 専用ノード SA
- Binary Authorization、アプリ層 CMEK

検証後は必ず destroy してください。GKE は課金が大きくなりやすいです。

## 公式照合で直した点 / カタログとの差

| カタログ（別 PoC）や旧記載 | 本サンプル / 公式 |
|---|---|
| リージョナル + 3 ゾーン | `location` がゾーンなら **zonal**。1 ゾーン 1 ノード |
| プライベートエンドポイントのみ | `private_cluster_config` なし。公開 API + ノード外部 IP |
| Dataplane V2 / Cloud DNS / NodeLocal DNS / max pods 32 | すべて未指定。datapath 既定は LEGACY。max pods 既定 110 |
| ノード `e2-small` / 専用 SA | `e2-medium` / デフォルト Compute SA + `cloud-platform` スコープ |
| ディスク「標準 PD」既定 | Provider のノード `disk_type` 未指定は `pd-balanced`（または hyperdisk）。本サンプルは **明示 pd-balanced / 30 GB**（未指定サイズは 100 GB） |
| WI を「クラスタ再作成 ○」と固定 | 現行 GKE は既存クラスタへの有効化が可能。本サンプルは作成時から明示 |
| シールドノードを曖昧に | クラスタ `enable_shielded_nodes` 既定 **true**。ノード Secure Boot 既定 **false**、整合性モニタリング既定 **true** |
| クラスタラベルを `labels` | Terraform は **`resource_labels`** |
| ディスク種類の GCP コンソール既定を pd-standard とだけ書いた | ノードプール Provider ドキュメントの既定に合わせた |
