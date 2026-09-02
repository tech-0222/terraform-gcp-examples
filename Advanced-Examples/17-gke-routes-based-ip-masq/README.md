# 17 - GKE routes-based + VPC Peering + ip-masq-agent

VPC Peering越しの通信が、GKEのネットワーキングモード（routes-based / VPC-native）によって成否が変わることを検証する応用サンプルです。**2つのGCP Project**を使います。

| プロジェクト | 役割 |
|---|---|
| Project A | routes-based GKEクラスタ + 踏み台を配置 |
| Project B | 宛先VM（nginx）を配置。**本サンプルではルーティング設定を一切変更しない** |

## 検証すること

1. **再現（失敗）**: Peeringのカスタムルート交換を無効にした状態で、PodからProject Bの宛先VMへcurlすると失敗する
2. **解決（成功）**: 宛先VM側の設定は一切変更せず、GKE側にip-masq-agentのConfigMapを適用するだけで、同じcurlが成功するようになる

## なぜ失敗するのか

routes-basedクラスタでは、PodのIP到達性はVPCの**カスタムルート**として表現されます（VPC-nativeクラスタの場合はSubnetのセカンダリレンジになり、挙動が異なります）。VPC PeeringではSubnetルートは常に交換されますが、カスタムルートは`export_custom_routes`/`import_custom_routes`を有効にしない限り交換されません。

本サンプルは常に`peering_custom_routes = false`です。Project Bは`pod_cidr`（Pod宛のカスタムルート）を一切知らないため、Pod IPを送信元にしたパケットの戻り経路が成立しません。

## なぜip-masq-agentで直るのか

ip-masq-agentは、宛先が`nonMasqueradeCIDRs`に含まれていなければ、送信元をPod IPからNode IPへSNATします。Node IPが属するSubnetの経路（Subnetルート）はPeeringで常に交換されるため、SNAT後は戻り経路が成立します。**宛先側（Project B）の設定を一切変更する必要がありません。**

GKEのノードには、ip-masq-agentのDaemonSetが**既定でインストール済み**です（ConfigMap未設定でも動作しており、`--nomasq-all-reserved-ranges`フラグにより、RFC 1918の予約範囲は基本的に非マスカレード＝Pod IPのまま送信されます）。本サンプルのConfigMapは、宛先VMのSubnet（`10.20.0.0/24`）だけを`nonMasqueradeCIDRs`から明示的に除外し、その宛先だけSNATを効かせます。

## 前提条件

- ADC認証済み
- **課金有効な2つの**検証用Project（Project A / Project B）
- 十分なクォータ

## ファイル構成

```text
17-gke-routes-based-ip-masq/
├── README.md
├── docs/
│   ├── PARAMETER.md              # terraform-docs（自動生成。手動編集しない）
│   └── RESOURCE-PARAMETERS.md    # コンソール / API / Terraform の対応（手書き）
├── DEPENDENCY-GRAPH.svg          # terraform graph（自動生成。手動編集しない）
├── .terraform.lock.hcl
├── versions.tf
├── provider.tf          # Project A（デフォルト）+ Project B（alias "b"）
├── variables.tf
├── network.tf            # VPC A/B、Subnet、Cloud NAT、Firewall、VPC Peering
├── bastion.tf             # 踏み台（Project A）: SA / IAM / VM
├── target_vm.tf           # 宛先VM（Project B）: nginx、IAM
├── gke.tf                 # GKE: routes-basedクラスタ（ip_allocation_policyにCIDRを直接指定）
├── outputs.tf
├── terraform.tfvars.example
└── k8s/
    ├── curlpod.yaml           # 検証用Pod
    └── ip-masq-config.yaml    # ip-masq-agent ConfigMap（Step 2で適用）
```

## 設定方法

```bash
cd Advanced-Examples/17-gke-routes-based-ip-masq
cp terraform.tfvars.example terraform.tfvars
```

```hcl
project_id        = "your-project-a-id"
target_project_id = "your-project-b-id"
iap_member        = "user:you@example.com"
```

## 使用方法

```bash
terraform init
terraform fmt -check
terraform validate
terraform plan
terraform apply
```

2つのプロジェクトにまたがるリソースを作成するため、`gcloud auth application-default login`のADCが両プロジェクトへのアクセス権を持っている必要があります。

## 確認方法

### 1. curlpodをデプロイする

```bash
gcloud compute scp k8s/curlpod.yaml \
  "$(terraform output -raw bastion_name):/tmp/curlpod.yaml" \
  --zone="$(terraform output -raw zone)" --tunnel-through-iap \
  --project="$(terraform output -raw project_id)"
```

```bash
# 踏み台の中で実行
gcloud container clusters get-credentials "$(terraform output -raw cluster_name)" \
  --zone="$(terraform output -raw zone)" --project="$(terraform output -raw project_id)"
kubectl apply -f /tmp/curlpod.yaml
kubectl wait --for=condition=ready pod/curlpod --timeout=90s
```

### 2. Step 1: 失敗を再現する

```bash
# 踏み台の中で実行
kubectl exec curlpod -- curl -m 5 -v "http://$(terraform output -raw target_vm_ip)/"
```

`Connection timed out`で失敗します。宛先VM側で`tcpdump`すると、Podからのパケットが一切届いていないことが確認できます。

```bash
gcloud compute ssh "$(terraform output -raw target_vm_name)" \
  --zone="$(terraform output -raw zone)" --tunnel-through-iap \
  --project="$(terraform output -raw target_project_id)" \
  --command="sudo timeout 10 tcpdump -ni any tcp port 80"
```

### 3. Step 2: ip-masq-agentを適用して解決する

```bash
sed -e "s|__POD_CIDR__|$(terraform output -raw pod_cidr)|" \
    -e "s|__SERVICES_CIDR__|172.17.0.0/20|" \
    -e "s|__GKE_SUBNET_CIDR__|10.10.0.0/28|" \
  k8s/ip-masq-config.yaml > /tmp/ip-masq-config.yaml
gcloud compute scp /tmp/ip-masq-config.yaml \
  "$(terraform output -raw bastion_name):/tmp/ip-masq-config.yaml" \
  --zone="$(terraform output -raw zone)" --tunnel-through-iap \
  --project="$(terraform output -raw project_id)"
```

```bash
# 踏み台の中で実行
kubectl apply -f /tmp/ip-masq-config.yaml
kubectl -n kube-system rollout restart ds/ip-masq-agent
kubectl -n kube-system rollout status ds/ip-masq-agent --timeout=60s
```

```bash
# 再度、踏み台の中で実行
kubectl exec curlpod -- curl -m 5 -v "http://$(terraform output -raw target_vm_ip)/"
```

`HTTP/1.1 200 OK`、本文は`hello from target-vm`が返れば成功です。宛先VM側の`tcpdump`では、送信元がPod IP（`172.16.x.x`）ではなくNode IP（GKE SubnetのIP）に変わっていることが確認できます。

## 削除方法

```bash
terraform destroy
```

**必ず destroy してください。** 2プロジェクトのGKE・VM・Cloud NATは利用中に料金が発生します。

## 注意点 / 費用

- **本サンプルは2つのGCP Projectを使う、最もコストが高い構成です。** 確認後は速やかに`destroy`してください
- GKEノードは`e2-standard-2`を使用しています。`e2-small`（2GB）ではKonnectivity AgentのメモリRequestを満たせず、Podが`Pending`のままになることが分かっています
- `peering_custom_routes`にはデフォルト値`false`のみを使う想定です。`true`にすると本サンプルの再現条件が崩れます
