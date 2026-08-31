# 13 - GKE Bastion + Memorystore for Redis Cluster

`11-gke-private-bastion`と同じ構成に、Memorystore for Redis Cluster（Private Service Connect接続）を追加した応用サンプルです。`12-gke-bastion-redis-instance`（Redis Instance / PSA接続）との違いを確認する目的も兼ねます。

Podから`redis-cli -c`（cluster mode）で実際に接続できることまで確認します。

## 12（Redis Instance）との違い

| 項目 | 12: Redis Instance | 13: Redis Cluster（本サンプル） |
|---|---|---|
| 接続方式 | Private Service Access（PSA） | Private Service Connect（PSC） |
| 追加のNetwork | Peering Rangeのみ | 専用Subnet（`/29`）+ Service Connection Policy |
| 接続先 | `host` / `port`（単一エンドポイント） | `discovery_endpoints`（Cluster全体のDiscovery Endpoint） |
| クライアント | 通常の`redis-cli` | `redis-cli -c`（cluster modeが必須） |

## 関係するサービス

| サービス | 役割 |
|---|---|
| GKE | プライベートクラスタ（Standard、ゾーナル） |
| Memorystore for Redis Cluster | Podからアクセスするキャッシュ |
| Private Service Connect | RedisをVPCへ接続するためのエンドポイント |
| Compute Engine | 踏み台VM（外部IPなし） |

## 作成されるGCPリソース

`11-gke-private-bastion`と同じリソースに加えて、以下を作成します。

| リソース | 内容 |
|---|---|
| `google_project_service` | redis / networkconnectivity / serviceconsumermanagement を追加 |
| `google_compute_subnetwork` | PSCエンドポイント用Subnet（`/29`） |
| `google_network_connectivity_service_connection_policy` | PSC用のService Connection Policy |
| `google_redis_cluster` | Memorystore for Redis Cluster（最小構成） |

## 前提条件

- ADC認証済み
- **課金有効な**検証用Project
- 十分なクォータ（CPU / IP）

## ファイル構成

```text
13-gke-bastion-redis-cluster/
├── README.md
├── docs/
│   ├── PARAMETER.md              # terraform-docs（自動生成。手動編集しない）
│   └── RESOURCE-PARAMETERS.md    # コンソール / API / Terraform の対応（手書き）
├── DEPENDENCY-GRAPH.svg          # terraform graph（自動生成。手動編集しない）
├── .terraform.lock.hcl
├── versions.tf
├── provider.tf
├── variables.tf
├── network.tf         # VPC / Subnet×2 / Cloud NAT / Firewall（準備）
├── bastion.tf          # 踏み台: SA / IAM / Firewall / VM
├── gke.tf              # GKE: ノード用SA/IAM、プライベートクラスタ、ノードプール
├── artifact_registry.tf # Artifact Registry、ノード用SAにreader権限
├── redis.tf             # Memorystore for Redis Cluster、PSC
├── outputs.tf
├── terraform.tfvars.example
└── k8s/
    ├── nginx-deployment.yaml         # 動作確認用（11と同じ）
    └── redis-test-deployment.yaml    # Redis Cluster接続テスト用（redis-cli -c）
```

## 設定方法

```bash
cd Advanced-Examples/13-gke-bastion-redis-cluster
cp terraform.tfvars.example terraform.tfvars
```

```hcl
project_id = "your-project-id"
iap_member = "user:you@example.com"
```

## 使用方法

```bash
terraform init
terraform fmt -check
terraform validate
terraform plan
terraform apply
```

GKEとRedis Clusterの両方の作成に時間がかかります。

## 確認方法

### Redis Clusterへ実際に接続できることを確認する

Clusterが作成できたことと、実際に接続できることは別です。踏み台経由でテスト用Podをデプロイし、`redis-cli -c`でPING・SET・GETを実行します。

```bash
sed -e "s|__REDIS_HOST__|$(terraform output -raw redis_host)|" \
    -e "s|__REDIS_PORT__|$(terraform output -raw redis_port)|" \
  k8s/redis-test-deployment.yaml > /tmp/redis-test-deployment.yaml
gcloud compute scp /tmp/redis-test-deployment.yaml \
  "$(terraform output -raw bastion_name):/tmp/redis-test-deployment.yaml" \
  --zone="$(terraform output -raw zone)" --tunnel-through-iap \
  --project="$(terraform output -raw project_id)"
```

```bash
# 踏み台の中で実行
gcloud container clusters get-credentials "$(terraform output -raw cluster_name)" \
  --zone="$(terraform output -raw zone)" --project="$(terraform output -raw project_id)"
kubectl apply -f /tmp/redis-test-deployment.yaml
kubectl wait --for=condition=ready pod -l app=redis-test --timeout=120s
kubectl logs -l app=redis-test
```

`PONG`と、SET/GETした`hello-from-pod`が表示されれば成功です。

## 削除方法

```bash
terraform destroy
```

**必ず destroy してください。** GKE・Redis Cluster・踏み台VM・Cloud NATは利用中に料金が発生します。

## 注意点 / 費用

- **GKEとRedis Clusterはどちらも高コストです。** Redis Clusterはシャード×ノードの構成のため、Redis Instance（12）より単価が高くなりやすい。検証後は必ずすぐに`destroy`してください
- 学習用に`replica_count = 0`（レプリカなし、HAなし）をデフォルトにしています。可用性が必要な場合は`replica_count`を1以上にします
- PSCエンドポイント用Subnetは`/29`（8アドレス）が推奨最小サイズです。GKE Subnet・コントロールプレーンCIDRと重複しない範囲を確保します
