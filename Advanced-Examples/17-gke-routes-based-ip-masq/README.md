# 17 - GKE + VPC Peering + ip-masq-agent（SNAT）

VPC Peering越しの Pod→VM 通信が失敗する構成を作り、ip-masq-agent の SNAT で復旧させる応用サンプル。**2つのGCP Project**を使う。

**当初は「routes-based クラスタでルートが交換されないため失敗する」と説明していた。再検証で覆った。**

| 当初の説明 | 実測 |
|---|---|
| routes-based クラスタ | `useIpAliases: true` で **VPC-native** |
| Pod CIDR 宛のルートは交換されない | `peering-route-...` として**交換されていた** |
| 失敗の原因はルートの非交換 | **宛先側のファイアウォール** |

| プロジェクト | 役割 |
|---|---|
| Project A | GKEクラスタ（VPC-native）+ 踏み台を配置 |
| Project B | 宛先VM（nginx）を配置。**本サンプルではルーティング設定を一切変更しない** |

## 検証すること

1. **再現（失敗）**: 宛先側が Pod CIDR を許可していない状態で、PodからProject Bの宛先VMへcurlすると失敗する
2. **解決（成功）**: 宛先VM側の設定は一切変更せず、GKE側にip-masq-agentのConfigMapを適用するだけで、同じcurlが成功するようになる

## なぜ失敗するのか

このクラスタは VPC-native で、Pod IP はサブネットのセカンダリレンジから出る。**サブネットのルートは Peering で常に交換される。** 実測でも Project B に `peering-route-...` が入っていた。

本サンプルは常に`peering_custom_routes = false`だが、**それが失敗の原因ではない。**

宛先側のファイアウォールが `gke_subnet_cidr`（`10.10.0.0/28`）だけを許可し、`pod_cidr`（`172.16.0.0/16`）を許可していないため、Pod IP を送信元にしたパケットが落ちる。

対照実験（ConfigMap 未適用＝SNATなし、ルート変更なし）:

```text
source_ranges                        curl http://10.20.0.10/
------------------------------------------------------------
10.10.0.0/28                         exit 28（タイムアウト）
10.10.0.0/28,172.16.0.0/16           http_code=200 ×3
10.10.0.0/28（戻す）                  exit 28 ×2
```

ip-masq-agent が「直す」のは、SNAT で送信元が Node IP になり、既存の許可条件を満たすようになるため。

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
├── gke.tf                 # GKE: VPC-nativeクラスタ（ip_allocation_policy にCIDRを直接指定）
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

`Connection timed out`で失敗する。宛先VM側で`tcpdump`しても、Podからのパケットは拾えなかった。ただし掲載した出力は件数の要約で、観測も15秒間だけ。その外で届いていないことまでは言えない。

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

`HTTP/1.1 200 OK`、本文は`hello from target-vm`が返れば成功。宛先VM側の`tcpdump`では、送信元がPod IP（`172.16.x.x`）から GKE Subnet のIPに変わる。Node IP と考えられるが、`kubectl get nodes -o wide` の `INTERNAL-IP` とは突き合わせていない。

## 削除方法

```bash
terraform destroy
```

**必ず destroy してください。** 2プロジェクトのGKE・VM・Cloud NATは利用中に料金が発生します。

## 注意点 / 費用

- **本サンプルは2つのGCP Projectを使う、最もコストが高い構成です。** 確認後は速やかに`destroy`してください
- GKEノードは`e2-standard-2`を使用しています。`e2-small`（2GB）ではKonnectivity AgentのメモリRequestを満たせず、Podが`Pending`のままになることが分かっています
- `peering_custom_routes`にはデフォルト値`false`のみを使う想定です。`true`にすると本サンプルの再現条件が崩れます
