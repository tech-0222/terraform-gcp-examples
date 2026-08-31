# 11 - GKE Private Cluster + Bastion

GKE Standard（ゾーナル、**プライベートエンドポイント＋プライベートノード**）と、そこへ接続するための踏み台（bastion）VMをセットで構築する応用サンプルです。

`Basic-Examples/07-gke` はコントロールプレーンも外部から到達できるパブリックエンドポイントですが、実務ではコントロールプレーンも公開しないプライベートクラスタが基本です。この場合`kubectl`を直接実行する経路がなくなるため、踏み台経由でのアクセスパターンが必要になります。

## 関係するサービス

| サービス | 役割 |
|---|---|
| GKE | プライベートクラスタ（Standard、ゾーナル） |
| Compute Engine | 踏み台VM（外部IPなし） |
| Identity-Aware Proxy | 踏み台・GKEノードへのSSH |
| Cloud NAT | 踏み台・GKEノードの外向き通信 |
| Artifact Registry | クラスタが参照するDockerリポジトリ |

## 作成されるGCPリソース

| リソース | 内容 |
|---|---|
| `google_project_service` | compute / container / artifactregistry |
| `google_compute_network` / `subnetwork` | 専用VPC、GKE用/踏み台用の2 Subnet |
| `google_compute_router` / `router_nat` / `address` | Cloud NAT（両Subnet） |
| `google_compute_firewall` | IAP SSH許可（踏み台・GKEノード、2本） |
| `google_service_account` | 踏み台用SA、GKEノード用SA |
| `google_container_cluster` / `node_pool` | プライベートクラスタ、Spot 1ノード |
| `google_compute_instance` | 踏み台VM |
| `google_artifact_registry_repository` | Dockerリポジトリ |

## 前提条件

- ADC認証済み
- **課金有効な**検証用Project
- 十分なクォータ（CPU / IP）

## 必要な権限（目安）

- Kubernetes Engine Admin
- Compute Network Admin / Compute Instance Admin
- Service Account Admin / IAM変更権限
- Artifact Registry Admin

## ファイル構成

```text
11-gke-private-bastion/
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
├── outputs.tf
├── terraform.tfvars.example
└── k8s/
    └── nginx-deployment.yaml     # 動作確認用（踏み台からkubectl applyで手動適用）
```

## 設定方法

```bash
cd Advanced-Examples/11-gke-private-bastion
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

### 1. 踏み台経由でクラスタに接続する

プライベートエンドポイントはVPC内（踏み台Subnet）からしか到達できません。踏み台にIAP SSHし、踏み台の中で`get-credentials`します。

```bash
gcloud compute ssh "$(terraform output -raw bastion_name)" \
  --zone="$(terraform output -raw zone)" \
  --tunnel-through-iap \
  --project="$(terraform output -raw project_id)"

# 踏み台の中で実行
gcloud container clusters get-credentials "$(terraform output -raw cluster_name)" \
  --zone="$(terraform output -raw zone)" \
  --project="$(terraform output -raw project_id)"
kubectl get nodes
```

### 2. Artifact Registry経由でnginxを配信できることを確認する

Nodeの起動確認だけでは、Podが実際に動くかはわかりません。イメージをpushし、踏み台経由でdeployし、port-forwardで実際に応答することを確認します。

```bash
# ローカル（Dockerが使える環境）で実行
gcloud auth configure-docker "$(terraform output -raw region)-docker.pkg.dev" --quiet
docker pull nginx:latest
docker tag nginx:latest "$(terraform output -raw artifact_registry_nginx_image)"
docker push "$(terraform output -raw artifact_registry_nginx_image)"
```

```bash
# 踏み台へマニフェストを転送して適用（ローカルから実行）
sed "s|__IMAGE__|$(terraform output -raw artifact_registry_nginx_image)|" \
  k8s/nginx-deployment.yaml > /tmp/nginx-deployment.yaml
gcloud compute scp /tmp/nginx-deployment.yaml \
  "$(terraform output -raw bastion_name):/tmp/nginx-deployment.yaml" \
  --zone="$(terraform output -raw zone)" --tunnel-through-iap \
  --project="$(terraform output -raw project_id)"
```

```bash
# 踏み台の中で実行
kubectl apply -f /tmp/nginx-deployment.yaml
kubectl get pods -l app=nginx
kubectl port-forward deployment/nginx 8080:80 &
curl -sS -o /dev/null -w "%{http_code}\n" http://localhost:8080
```

## 削除方法

```bash
terraform destroy
```

**必ず destroy してください。** GKE・踏み台VM・Cloud NATは利用中に料金が発生します。

## 注意点 / 費用

- **GKEは高コストです。** 検証後は必ずすぐに`destroy`してください
- Spotノードは予告なく回収される可能性があります
- コントロールプレーンのCIDR（`master_ipv4_cidr_block`）はVPC内の他のCIDRと重複できません
- Workload Identityは有効化のみ（Pool設定まで）。実際のPodからのGSA借用は`03-gke-workload-identity-gcs`を参照してください
