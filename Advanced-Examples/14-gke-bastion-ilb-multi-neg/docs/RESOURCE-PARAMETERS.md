# 14 - リソースパラメータ対応

このファイルは**本サンプルのリージョナルGKEクラスタ・踏み台・Internal HTTP LB（NEG）**について対応づけます。自動生成の`docs/PARAMETER.md`とは別物です。VPC/踏み台の基本部分は`11-gke-private-bastion`と同じ構成のため、ここではGKEのクラスタ形状の変更点とILB部分を中心に記載します。

一次情報:

- [google_container_cluster](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_cluster)
- [google_compute_region_backend_service](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_backend_service)
- [Google Cloud: Internal HTTP(S) Load Balancing](https://cloud.google.com/load-balancing/docs/l7-internal)
- [Google Cloud: Standalone zonal NEGs / GKE NEG](https://cloud.google.com/kubernetes-engine/docs/how-to/standalone-neg)

## 確認コマンド

```bash
gcloud container clusters describe "$(terraform output -raw cluster_name)" \
  --region="$(terraform output -raw region)" --format=json
gcloud compute network-endpoint-groups list --filter="name~neg-app"
gcloud compute backend-services list --regions="$(terraform output -raw region)"
gcloud compute forwarding-rules list --regions="$(terraform output -raw region)"
```

## ネットワーク（VPC/踏み台）

`11-gke-private-bastion`と同じ。詳細はそちらの`docs/RESOURCE-PARAMETERS.md`を参照。CIDRのみ再掲する。

| 項目 | 本サンプル |
|---|---|
| GKE Subnet | `10.40.0.0/24`（Pods `10.41.0.0/16`、Services `10.42.0.0/20`） |
| 踏み台Subnet | `10.43.0.0/24` |
| GKEコントロールプレーン | `172.16.4.0/28` |
| ILB proxy-only Subnet | `10.44.0.0/23`（`enable_ilb=true`時のみ作成） |

## google_container_cluster.primary（11との差分）

| 項目 | 本サンプル | 区分 | Terraform | 備考 |
|---|---|---|---|---|
| ロケーション種別 | リージョナル | 明示 | `location = var.region` | `11`はゾーナル（`location = var.zone`）。NEGがゾーンごとに作られるため、複数ゾーンにノードが要る |
| ノード配置 | 3ゾーンにゾーンごと1台（計3台） | 明示 | `node_locations = var.gke_zones`、`node_count = 1` | `node_count`はゾーンごとに適用される値のため、3ゾーンで合計3ノードになる |

## Internal HTTP LB（enable_ilb=true時）

NEGはGKEのServiceに付けた`cloud.google.com/neg`アノテーションからGKEコントローラが作成する。Terraformが直接管理するリソースではないため、Terraform側からはURL文字列（プロジェクト・ゾーン・NEG名を組み立てた文字列）として参照するだけで、存在チェックはできない。存在しないNEGを参照した状態で`apply`すると、Terraformの計画段階ではなく実際のAPI呼び出し時に404で失敗する。

| 項目 | 本サンプル | 区分 | Terraform | 備考 |
|---|---|---|---|---|
| proxy-only Subnet | `/23`、`REGIONAL_MANAGED_PROXY` | 明示 | `google_compute_subnetwork.proxy_only` | `INTERNAL_MANAGED`方式（Envoyベース）に必須。旧来のパススルー方式（`INTERNAL`）では不要 |
| Backend Service | `load_balancing_scheme = "INTERNAL_MANAGED"`、`protocol = "HTTP"` | 明示 | `google_compute_region_backend_service.bs_app_*` | `backend`ブロックはゾーンごとに1つ、NEGを名前で参照する動的ブロック |
| Health Check | ポート8080、パス`/` | 明示 | `google_compute_region_health_check.hc_app_*` | app-a/b/cそれぞれに専用のHealth Check |
| VIP | GKE Subnet内、`SHARED_LOADBALANCER_VIP` | 明示 | `google_compute_address.ilb_vip` | `10.40.0.250`（Subnet上位のアドレス。ノードのIPは1段階目のapply時点で既に割り当て済みのため、低いアドレスとの衝突を避けている） |
| Forwarding Rule | :81/:82/:83、`INTERNAL_MANAGED` | 明示 | `google_compute_forwarding_rule.fr_81/82/83` | 同一VIPに対し、ポートごとに異なるURL Map（≒異なるバックエンド）を割り当てる |
| Firewall（Health Check） | `130.211.0.0/22`、`35.191.0.0/16` → tcp/8080 | 明示 | `google_compute_firewall.allow_ilb_health_check` | Googleのヘルスチェックプローバー送信元の固定レンジ |
| Firewall（proxy-only） | proxy-only Subnet → tcp/8080 | 明示 | `google_compute_firewall.allow_ilb_proxies` | `INTERNAL_MANAGED`はEnvoyプロキシ経由でバックエンドに到達するため必要 |

未指定（デフォルト）の項目はコンソール/APIのデフォルト値に従う。推測での記載はしない。
