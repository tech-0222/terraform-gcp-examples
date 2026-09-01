# 16 - GKE Bastion + Dataplane V2 + NetworkPolicy

`11-gke-private-bastion`と同じ踏み台構成をベースに、GKE Dataplane V2（Cilium/eBPFベース）を有効化した応用サンプルです。Dataplane V2はNetworkPolicyの強制がビルトインされており、追加のCNI（Calico等）なしにPod間通信を制限できます。

「Dataplane V2を有効化した」ことと「NetworkPolicyが実際に意図通り機能する」ことは別です。ラベルで許可したPodからは通り、許可していないPodからは遮断されることを、実際にPodを起動して確認します。

## 11との違い

| 項目 | 11 | 16: Dataplane V2（本サンプル） |
|---|---|---|
| `datapath_provider` | 未指定（デフォルト、iptablesベースのkube-proxy） | **`ADVANCED_DATAPATH`**（Cilium/eBPFベース） |
| NetworkPolicy | 使用しない | Dataplane V2にビルトイン。追加設定なしで強制される |

**Dataplane V2が有効なクラスタでは、別途`network_policy`ブロック（Calicoベースのアドオン）を設定してはいけません。** 両方を有効にすると、`apply`が次のエラーで失敗します。

```text
Enabling NetworkPolicy for clusters with DatapathProvider=ADVANCED_DATAPATH is not allowed.
```

## 関係するサービス

| サービス | 役割 |
|---|---|
| GKE | プライベートクラスタ（Standard、ゾーナル、Dataplane V2有効） |
| NetworkPolicy | Pod間通信をラベルで制限する標準Kubernetesリソース |
| Compute Engine | 踏み台VM（外部IPなし） |

## 前提条件

- ADC認証済み
- **課金有効な**検証用Project

## ファイル構成

```text
16-gke-dataplane-v2-networkpolicy/
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
├── gke.tf              # GKE: ノード用SA/IAM、Dataplane V2有効化
├── artifact_registry.tf # Artifact Registry、ノード用SAにreader権限
├── outputs.tf
├── terraform.tfvars.example
└── k8s/
    ├── nginx-deployment.yaml         # 動作確認用（11と同じ）
    └── netpol-demo.yaml              # サーバPod + Service + NetworkPolicy
```

## 設定方法

```bash
cd Advanced-Examples/16-gke-dataplane-v2-networkpolicy
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

## 確認方法

### 1. サーバPod・Service・NetworkPolicyをデプロイする

```bash
gcloud compute scp k8s/netpol-demo.yaml \
  "$(terraform output -raw bastion_name):/tmp/netpol-demo.yaml" \
  --zone="$(terraform output -raw zone)" --tunnel-through-iap \
  --project="$(terraform output -raw project_id)"
```

```bash
# 踏み台の中で実行
gcloud container clusters get-credentials "$(terraform output -raw cluster_name)" \
  --zone="$(terraform output -raw zone)" --project="$(terraform output -raw project_id)"
kubectl apply -f /tmp/netpol-demo.yaml
kubectl wait --for=condition=ready pod -l app=netpol-server --timeout=90s
```

### 2. 許可したラベルのPodからは通信できることを確認する

`role=netpol-allowed`ラベルを付けたPodから接続します。`--rm -it`は`gcloud compute ssh --command=`のような非対話実行では接続が不安定になったため、`sleep`で待機させたPodに`exec`する方式にしています。

```bash
kubectl run netpol-debug --image=busybox:1.36 --restart=Never \
  --labels="role=netpol-allowed" -- sleep 3600
kubectl wait --for=condition=ready pod/netpol-debug --timeout=60s
kubectl exec netpol-debug -- wget -qO- --timeout=5 http://netpol-server:8080
```

`authorized-reached`が返れば成功です。

### 3. 許可していないPodからは遮断されることを確認する（apply成功とは別の確認）

ラベルなしのPodから、同じServiceへ接続を試みます。

```bash
kubectl run netpol-debug-denied --image=busybox:1.36 --restart=Never -- sleep 3600
kubectl wait --for=condition=ready pod/netpol-debug-denied --timeout=60s
kubectl exec netpol-debug-denied -- wget -qO- --timeout=5 http://netpol-server:8080
```

`wget: download timed out`で失敗すれば、NetworkPolicyが意図通り機能しています。

```bash
# 後片付け（デバッグ用Podの削除）
kubectl delete pod netpol-debug netpol-debug-denied --ignore-not-found=true
```

## 削除方法

```bash
terraform destroy
```

**必ず destroy してください。** GKE・踏み台VM・Cloud NATは利用中に料金が発生します。

## 注意点 / 費用

- **`network_policy`ブロック（Calicoベース）は設定しないでください。** Dataplane V2との併用はTerraform apply時にエラーになります
- 本サンプルはDataplane V2とNetworkPolicyの検証に範囲を絞っています。Filestore/GCS FUSE CSI、Secret Manager CSI、NodeLocal DNSCache等の他のハードニング設定は扱いません
