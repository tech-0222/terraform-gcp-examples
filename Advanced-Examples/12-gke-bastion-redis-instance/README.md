# 12 - GKE Bastion + Memorystore for Redis

`11-gke-private-bastion`（GKE Standardプライベートクラスタ＋踏み台）と同じ構成に、Memorystore for Redis（BASIC）を追加した応用サンプルです。独立したRoot Moduleとして、VPC・踏み台・GKEを含めて一式作成します。

Podから`redis-cli`で実際に接続できることまで確認します。

## 関係するサービス

| サービス | 役割 |
|---|---|
| GKE | プライベートクラスタ（Standard、ゾーナル） |
| Memorystore for Redis | Podからアクセスするキャッシュ（BASIC） |
| Private Service Access | RedisをVPCへ接続するためのPeering |
| Compute Engine | 踏み台VM（外部IPなし） |

## 作成されるGCPリソース

`11-gke-private-bastion`と同じリソース（VPC/Subnet/Cloud NAT/Firewall/踏み台/GKE/Artifact Registry）に加えて、以下を作成します。

| リソース | 内容 |
|---|---|
| `google_project_service` | redis / servicenetworking を追加 |
| `google_compute_global_address` | PSA用Peering Range |
| `google_service_networking_connection` | PSA接続 |
| `google_redis_instance` | Memorystore for Redis（BASIC、1GB） |

## 前提条件

- ADC認証済み
- **課金有効な**検証用Project
- 十分なクォータ（CPU / IP）

## 必要な権限（目安）

`11-gke-private-bastion`と同じ権限に加え、Redis Adminが必要です。

## ファイル構成

```text
12-gke-bastion-redis-instance/
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
├── redis.tf             # Memorystore for Redis、PSA
├── outputs.tf
├── terraform.tfvars.example
└── k8s/
    ├── nginx-deployment.yaml         # 動作確認用（11と同じ）
    └── redis-test-deployment.yaml    # Redis接続テスト用（踏み台からkubectl applyで手動適用）
```

## 設定方法

```bash
cd Advanced-Examples/12-gke-bastion-redis-instance
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

GKE作成に十数分かかることがあります。

## 確認方法

### Redisへ実際に接続できることを確認する

Instanceが作成できたことと、実際に接続できることは別です。踏み台経由でテスト用Podをデプロイし、`redis-cli`でPING・SET・GETを実行します。

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

**必ず destroy してください。** GKE・Redis・踏み台VM・Cloud NATは利用中に料金が発生します。

## 注意点 / 費用

- **GKEとRedisはどちらも高コストです。** 検証後は必ずすぐに`destroy`してください
- Redisは`BASIC`（レプリカなし）です。可用性が必要な用途には`STANDARD_HA`を検討してください
- PSAのPeering Rangeは、GKEサブネット（`10.40.0.0/24`等）やコントロールプレーンCIDR（`172.16.4.0/28`）と重複しないサイズ（`/24`）で自動確保します
