# 16 - リソースパラメータ対応

このファイルは**本サンプルのDataplane V2 + NetworkPolicy**について対応づけます。自動生成の`docs/PARAMETER.md`とは別物です。VPC/踏み台の基本部分は`11-gke-private-bastion`と同じ構成のため、ここではDataplane V2の差分を中心に記載します。

一次情報:

- [Google Cloud: GKE Dataplane V2](https://cloud.google.com/kubernetes-engine/docs/how-to/dataplane-v2)
- [Kubernetes: Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [google_container_cluster](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_cluster)

## 確認コマンド

```bash
gcloud container clusters describe "$(terraform output -raw cluster_name)" \
  --zone="$(terraform output -raw zone)" --format="value(networkConfig.datapathProvider)"
kubectl get networkpolicy
```

## ネットワーク（VPC/踏み台）

`11-gke-private-bastion`と同じ。詳細はそちらの`docs/RESOURCE-PARAMETERS.md`を参照。CIDRのみ再掲する。

| 項目 | 本サンプル |
|---|---|
| GKE Subnet | `10.40.0.0/24`（Pods `10.41.0.0/16`、Services `10.42.0.0/20`） |
| 踏み台Subnet | `10.43.0.0/24` |
| GKEコントロールプレーン | `172.16.4.0/28` |

## google_container_cluster.primary（11との差分）

一次情報（Google Cloud公式ドキュメント）で確認した内容を根拠とする。

| 項目 | 本サンプル | 区分 | Terraform | 備考 |
|---|---|---|---|---|
| `datapath_provider` | `ADVANCED_DATAPATH` | 明示 | `datapath_provider = "ADVANCED_DATAPATH"` | providerのフィールド説明: 「By default, uses the IPTables-based kube-proxy implementation.」を`ADVANCED_DATAPATH`（Cilium/eBPF、Dataplane V2）に変更 |
| `network_policy`ブロック | **設定しない** | 意図的に省略 | （なし） | Google Cloud公式ドキュメント: 「GKE Dataplane V2 comes with Kubernetes network policy enforcement built-in. This means that you don't need to enable network policy in clusters that use GKE Dataplane V2.」設定すると`Enabling NetworkPolicy for clusters with DatapathProvider=ADVANCED_DATAPATH is not allowed`でapplyが失敗する |

## NetworkPolicy（Kubernetesリソース、Terraform管理外）

| 項目 | 本サンプル | 備考 |
|---|---|---|
| 対象Pod | `app: netpol-server`ラベルのPod | `podSelector`で指定 |
| 許可元 | `role: netpol-allowed`ラベルのPodのみ | `ingress.from.podSelector`で指定 |
| 許可ポート | TCP 8080 | サーバの`http-echo`が listen するポート |
| 適用範囲 | `Ingress`のみ | Egressは制限しない |

未指定（デフォルト）の項目はコンソール/APIのデフォルト値に従う。推測での記載はしない。
