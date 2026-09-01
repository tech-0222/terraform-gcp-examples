# 15 - リソースパラメータ対応

このファイルは**本サンプルのDual EndpointプライベートGKEクラスタ**について対応づけます。自動生成の`docs/PARAMETER.md`とは別物です。VPC/踏み台の基本部分は`11-gke-private-bastion`と同じ構成のため、ここではエンドポイント設定の差分を中心に記載します。

一次情報:

- [google_container_cluster](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_cluster)
- [Google Cloud: Private cluster access to control plane](https://cloud.google.com/kubernetes-engine/docs/how-to/private-clusters)

## 確認コマンド

```bash
gcloud container clusters describe "$(terraform output -raw cluster_name)" \
  --zone="$(terraform output -raw zone)" --format=json
```

## ネットワーク（VPC/踏み台）

`11-gke-private-bastion`と同じ。詳細はそちらの`docs/RESOURCE-PARAMETERS.md`を参照。CIDRのみ再掲する。

| 項目 | 本サンプル |
|---|---|
| GKE Subnet | `10.40.0.0/24`（Pods `10.41.0.0/16`、Services `10.42.0.0/20`） |
| 踏み台Subnet | `10.43.0.0/24` |
| GKEコントロールプレーン | `172.16.4.0/28` |

## google_container_cluster.primary（11との差分）

`terraform providers schema -json`で確認したprovider（google ~> 7.0、実際に検証したバージョンは7.46.0）のフィールド説明を根拠とする。

| 項目 | 本サンプル | 区分 | Terraform | 備考 |
|---|---|---|---|---|
| `enable_private_endpoint` | **`false`** | 明示 | `private_cluster_config.enable_private_endpoint` | providerのフィールド説明: 「When true, the cluster's private endpoint is used as the cluster endpoint and access through the public endpoint is disabled. When false, either endpoint can be used.」`true`のままでは`master_authorized_networks`にパブリックIPを追加してもパブリックエンドポイントは有効化されない（元にしたPoCのコードはここが`true`のままで、Dual Endpointとして機能しない設定だった） |
| `enable_private_nodes` | `true` | 明示 | `private_cluster_config.enable_private_nodes` | ノードにはパブリックIPを付与しない。`11`と同じ |
| Master Authorized Networks | 踏み台Subnet CIDR + `admin_public_cidr` | 明示 | `master_authorized_networks_config`（`cidr_blocks`を2つ） | この設定がないと、パブリックエンドポイントは無制限に公開される |
| `public_endpoint`（出力） | コンソール/APIが払い出す値 | 未指定（コンピューテッド） | `private_cluster_config[0].public_endpoint` | `enable_private_endpoint=false`の場合のみ意味を持つ |

## gcloudのデフォルトエンドポイント選択（実機で確認した挙動）

`enable_private_endpoint=false`の場合、`gcloud container clusters get-credentials`は**VPC内（踏み台）から実行してもデフォルトでパブリックエンドポイントのIPをkubeconfigに書き込む**。実際に踏み台から`--internal-ip`なしで実行したところ、`dial tcp <public_endpoint>:443: i/o timeout`で失敗した（踏み台のCloud NAT出口IPは`admin_public_cidr`に含まれないため）。`--internal-ip`を付けて再実行すると成功した。

`11`（`enable_private_endpoint=true`）ではこの問題は起きない。エンドポイントが1つしか存在しないため、`get-credentials`は常にそのプライベートエンドポイントを返す。Dual Endpointにした結果として新たに気にする必要が生まれた点であり、元にしたPoCの手順書（`GKE-Basic-readme.md`）はこの`--internal-ip`の必要性に触れていなかった。

## admin_public_cidr

| 項目 | 本サンプル | 区分 | Terraform | 備考 |
|---|---|---|---|---|
| 値 | 手元の端末のグローバルIP + `/32`（デフォルトなし） | 明示（必須変数） | `var.admin_public_cidr` | `curl -s https://ifconfig.me`で取得。デフォルトを設定しない理由は、誤って`0.0.0.0/0`相当の緩い値のまま気づかず`apply`する事故を避けるため |

未指定（デフォルト）の項目はコンソール/APIのデフォルト値に従う。推測での記載はしない。
