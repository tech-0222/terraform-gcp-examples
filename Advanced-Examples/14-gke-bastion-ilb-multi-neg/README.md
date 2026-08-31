# 14 - GKE Bastion + Internal HTTP LB (NEG, GKE Pod backends)

`11-gke-private-bastion`と同じ踏み台構成に、Internal HTTP LB（INTERNAL_MANAGED）を追加した応用サンプルです。バックエンドはGKEのPodを直接指すNetwork Endpoint Group（NEG）で、`08-regional-external-alb-neg`（手動作成のCompute InstanceをNEGにする構成）とは異なり、GKEのServiceに`cloud.google.com/neg`アノテーションを付けるとGKEコントローラがNEGを自動作成します。

3つのバックエンド（app-a/b/c）を、共有VIPのポート（:81/:82/:83）で振り分けます。GKEクラスタは`11`〜`13`と異なり**リージョナル・3ゾーン（ゾーンごと1ノード）**です。NEGはゾーンごとに作られるため、複数ゾーンにPodが分散していないと「複数NEGバックエンド」の構成を確認できません。

## 11〜13との違い

| 項目 | 11〜13 | 14: ILB + Multi NEG（本サンプル） |
|---|---|---|
| GKEクラスタ | ゾーナル（1ノード） | **リージョナル・3ゾーン（ゾーンごと1ノード、計3ノード）** |
| apply | 1段階 | **2段階**（`enable_ilb=false`→Pod/Service作成→NEG作成待ち→`enable_ilb=true`） |
| NEG | 使用しない | GKE Serviceのアノテーションから自動作成（Terraform管理外） |

## 関係するサービス

| サービス | 役割 |
|---|---|
| GKE | プライベートクラスタ（Standard、リージョナル・3ゾーン） |
| Internal HTTP LB（INTERNAL_MANAGED） | VPC内部向けのL7ロードバランサ |
| Network Endpoint Group（NEG） | GKE PodをLBバックエンドとして直接参照する仕組み |
| Compute Engine | 踏み台VM（外部IPなし） |

## 作成されるGCPリソース

`11-gke-private-bastion`と同じリソースに加えて、以下を`enable_ilb=true`で作成します。

| リソース | 内容 |
|---|---|
| `google_compute_subnetwork.proxy_only` | INTERNAL_MANAGED方式に必須のproxy-only Subnet |
| `google_compute_firewall` ×2 | Health Check送信元・proxy-onlyサブネットからの到達を許可 |
| `google_compute_region_health_check` ×3 | app-a/b/c用 |
| `google_compute_region_backend_service` ×3 | NEG（`neg-app-a/b/c`）をバックエンドに持つ |
| `google_compute_region_url_map` ×3、`target_http_proxy` ×3 | ポートごとの振り分け先 |
| `google_compute_address.ilb_vip` | 共有VIP |
| `google_compute_forwarding_rule` ×3 | :81/:82/:83 |

GKEクラスタは`11`と異なりリージョナル・3ゾーン（ゾーンごと1ノード、計3ノード）にしています。

## 前提条件

- ADC認証済み
- **課金有効な**検証用Project
- 十分なクォータ（CPU × 3ゾーン分・IP）

## ファイル構成

```text
14-gke-bastion-ilb-multi-neg/
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
├── gke.tf              # GKE: ノード用SA/IAM、リージョナル・3ゾーンのプライベートクラスタ
├── artifact_registry.tf # Artifact Registry、ノード用SAにreader権限
├── ilb.tf                # Internal HTTP LB（enable_ilbで有効化）
├── outputs.tf
├── terraform.tfvars.example
└── k8s/
    ├── nginx-deployment.yaml         # 動作確認用（11と同じ）
    └── ilb-app-a.yaml, ilb-app-b.yaml, ilb-app-c.yaml  # ILBバックエンド（NEGアノテーション付き）
```

## 設定方法

```bash
cd Advanced-Examples/14-gke-bastion-ilb-multi-neg
cp terraform.tfvars.example terraform.tfvars
```

```hcl
project_id = "your-project-id"
iap_member = "user:you@example.com"
```

## 使用方法（2段階apply）

NEGはGKEのServiceアノテーションからGKEコントローラが作成するため、Terraformだけでは完結しません。`enable_ilb=false`（デフォルト）でクラスタを作り、Podをデプロイし、NEGの作成を待ってから`enable_ilb=true`でLBを作ります。

```bash
terraform init
terraform fmt -check
terraform validate
terraform plan
terraform apply
```

```bash
# 踏み台へマニフェストを転送し、kubectl apply（詳細は「確認方法」参照）
# NEG作成を1〜2分待つ
terraform apply -var="enable_ilb=true"
```

GKEクラスタ（3ゾーン）の作成に時間がかかります。

## 確認方法

### 1. app-a/b/cをデプロイし、NEGが作られたことを確認する

```bash
for f in nginx-deployment.yaml ilb-app-a.yaml ilb-app-b.yaml ilb-app-c.yaml; do
  gcloud compute scp "k8s/$f" \
    "$(terraform output -raw bastion_name):/tmp/$f" \
    --zone="$(terraform output -raw zone)" --tunnel-through-iap \
    --project="$(terraform output -raw project_id)"
done
```

```bash
# 踏み台の中で実行
gcloud container clusters get-credentials "$(terraform output -raw cluster_name)" \
  --region="$(terraform output -raw region)" --project="$(terraform output -raw project_id)"
kubectl apply -f /tmp/ilb-app-a.yaml -f /tmp/ilb-app-b.yaml -f /tmp/ilb-app-c.yaml
kubectl get nodes -o wide   # 3ゾーンにReadyノードがあること
```

ローカル(踏み台の外)から、NEGが3つとも作成されるまで待ちます。

```bash
gcloud compute network-endpoint-groups list \
  --project="$(terraform output -raw project_id)" \
  --filter="name~neg-app"
```

`neg-app-a`/`neg-app-b`/`neg-app-c`が3ゾーンそれぞれに表示されたら次へ進みます（通常1〜2分）。

### 2. `enable_ilb=true`でILBを作成する

```bash
terraform apply -var="enable_ilb=true"
```

### 3. 踏み台からVIPの3ポートへ実際に接続できることを確認する

ILBが作成できたことと、意図したバックエンドへ実際に振り分けられることは別です。

```bash
# 踏み台の中で実行
curl -s "http://$(terraform output -raw ilb_vip):81/"
curl -s "http://$(terraform output -raw ilb_vip):82/"
curl -s "http://$(terraform output -raw ilb_vip):83/"
```

`backend-a`・`backend-b`・`backend-c`がそれぞれ返れば成功です。

## 削除方法

```bash
terraform destroy
```

**必ず destroy してください。** GKE（3ノード）・ILB・踏み台VM・Cloud NATは利用中に料金が発生します。

## 注意点 / 費用

- **本サンプルはリージョナル・3ゾーンのGKEクラスタを使うため、11〜13より高コストです。** ノード数が3倍になります。確認後は速やかに`destroy`してください
- `enable_ilb`はNEG作成前に`true`にすると、Terraformのapply自体が404エラーで失敗します（NEGはTerraform管理外のリソースのため、存在確認はTerraformの計画段階ではできません）。必ず「確認方法」の順序で進めてください
- `ilb_vip_address`はGKE Subnet内の未使用アドレスを指定します。ノードのIPは`terraform apply`（1段階目）の時点で既に割り当てられているため、低いアドレス（`.1`/`.2`など）は衝突するリスクがあります。本サンプルではSubnetの上位に近い`10.40.0.250`を使っています
