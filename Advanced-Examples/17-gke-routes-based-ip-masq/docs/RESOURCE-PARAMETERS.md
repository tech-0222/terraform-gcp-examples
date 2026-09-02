# 17 - リソースパラメータ対応

このファイルは**本サンプルのroutes-based GKEクラスタ、VPC Peering、ip-masq-agent**について対応づけます。自動生成の`docs/PARAMETER.md`とは別物です。2プロジェクト構成の応用サンプルのため、`11-gke-private-bastion`との共通点は少ない。

一次情報:

- [Google Cloud: Create routes-based clusters](https://cloud.google.com/kubernetes-engine/docs/how-to/routes-based-cluster)
- [Google Cloud: IP masquerade agent](https://cloud.google.com/kubernetes-engine/docs/concepts/ip-masquerade-agent)
- [Google Cloud: VPC Network Peering](https://cloud.google.com/vpc/docs/vpc-peering)
- [google_container_cluster](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_cluster)
- [google_compute_network_peering](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network_peering)

## 確認コマンド

```bash
gcloud compute routes list --project="$(terraform output -raw project_id)"
gcloud compute routes list --project="$(terraform output -raw target_project_id)"
gcloud compute networks peerings list --network="$(terraform output -raw project_id)" --project="$(terraform output -raw project_id)"
```

## google_container_cluster.primary（routes-based）

| 項目 | 本サンプル | 区分 | Terraform | 備考 |
|---|---|---|---|---|
| ネットワーキングモード | routes-based | 明示（間接） | `ip_allocation_policy`に`cluster_ipv4_cidr_block`/`services_ipv4_cidr_block`を直接指定 | セカンダリレンジ名（`cluster_secondary_range_name`）を指定するとVPC-nativeになる。この2つは排他 |
| Pod CIDR | `172.16.0.0/16` | 明示 | `var.pod_cidr` | クラスタ作成後、VPCの**カスタムルート**として各ノードのPod宛レンジが登録される |
| Service CIDR | `172.17.0.0/20` | 明示 | `var.services_cidr` | |
| ノード | 1台、`e2-standard-2`、Spot | 明示 | `node_config.spot = true` | `e2-small`ではKonnectivity AgentのメモリRequestを満たせずPodがPendingになることを確認済み |

## VPC Peering（custom routesスイッチ）

| 項目 | 本サンプル | 区分 | Terraform | 備考 |
|---|---|---|---|---|
| `export_custom_routes` / `import_custom_routes` | 常に`false` | 明示 | `var.peering_custom_routes`（デフォルト`false`） | `false`のまま。Pod CIDR（カスタムルート）はProject Bに伝播しない。これが本サンプルの前提条件 |
| Subnetルート | 常に交換される（無効化不可） | GCPの仕様 | — | Node Subnet（`10.10.0.0/28`）宛の経路は`peering_custom_routes`に関係なく常にProject Bへ伝播する。ip-masq-agentのSNATが効く理由はこれ |

## ip-masq-agent（Kubernetesリソース、Terraform管理外）

| 項目 | 本サンプル | 備考 |
|---|---|---|
| 既定動作 | ConfigMap未適用でもDaemonSetは動作中 | GKEの標準コンポーネント。`--nomasq-all-reserved-ranges`により、RFC 1918宛は既定で非マスカレード（Pod IPのまま） |
| `nonMasqueradeCIDRs` | Pod CIDR・Service CIDR・GKE Subnet CIDRのみ | 宛先VMのSubnet（`10.20.0.0/24`）を**含めない**ことで、その宛先だけSNATが有効になる |
| 適用方法 | `kubectl apply` + `kubectl rollout restart ds/ip-masq-agent` | ConfigMapの変更はDaemonSetの自動再読み込み対象外のため、明示的な再起動が必要 |

## ファイアウォール（宛先側の設計は変更しない）

| 項目 | 本サンプル | 区分 | Terraform | 備考 |
|---|---|---|---|---|
| Project B: HTTP許可元 | GKE Subnet CIDR（`10.10.0.0/28`）のみ | 明示 | `google_compute_firewall.b_allow_http_from_a_nodes` | Pod CIDRは含まれない。ip-masq-agentでSNATしない限り、Firewallでも通らない構成 |

未指定（デフォルト）の項目はコンソール/APIのデフォルト値に従う。推測での記載はしない。
