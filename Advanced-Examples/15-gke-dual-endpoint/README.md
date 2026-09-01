# 15 - GKE Bastion + Dual Endpoint（Private + Public、IP制限付き）

`11-gke-private-bastion`と同じ踏み台構成をベースに、GKEコントロールプレーンを**プライベートエンドポイントとパブリックエンドポイントの両方**で到達可能にした応用サンプルです。パブリック側は`master_authorized_networks`で許可IPを制限します。

## 11との違い

`11`は`enable_private_endpoint = true`でパブリックエンドポイントを完全に無効化していました。本サンプルはこれを`false`にし、`master_authorized_networks_config`に踏み台Subnetと管理者の公開IPの両方を許可します。

| 項目 | 11: 完全プライベート | 15: Dual Endpoint（本サンプル） |
|---|---|---|
| `enable_private_endpoint` | `true` | **`false`** |
| パブリックエンドポイント | 無効（`master_authorized_networks`を設定しても到達不可） | 有効。ただし`admin_public_cidr`のみ許可 |
| ローカルPCから直接kubectl | 不可（踏み台必須） | 可能（`admin_public_cidr`と一致する場合のみ） |

**`enable_private_endpoint = true`のまま`master_authorized_networks`にパブリックIPを追加しても、パブリックエンドポイントは有効になりません。** providerのスキーマ定義どおり、`true`は「パブリックエンドポイント経由のアクセスを無効化する」フラグです。Dual Endpointを実現するには`false`にする必要があります（`docs/RESOURCE-PARAMETERS.md`参照）。

## 関係するサービス

| サービス | 役割 |
|---|---|
| GKE | プライベートクラスタ（Standard、ゾーナル、Private + Public Endpoint併用） |
| Compute Engine | 踏み台VM（外部IPなし） |

## 前提条件

- ADC認証済み
- **課金有効な**検証用Project
- 手元の端末のグローバルIP（`curl -4 -s https://ifconfig.me`で取得）

## ファイル構成

```text
15-gke-dual-endpoint/
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
├── gke.tf              # GKE: ノード用SA/IAM、Dual Endpointのプライベートクラスタ
├── artifact_registry.tf # Artifact Registry、ノード用SAにreader権限
├── outputs.tf
├── terraform.tfvars.example
└── k8s/
    └── nginx-deployment.yaml         # 動作確認用（11と同じ）
```

## 設定方法

```bash
cd Advanced-Examples/15-gke-dual-endpoint
cp terraform.tfvars.example terraform.tfvars
curl -4 -s https://ifconfig.me   # 表示されたIPを admin_public_cidr に /32 で設定
```

```hcl
project_id         = "your-project-id"
iap_member         = "user:you@example.com"
admin_public_cidr  = "203.0.113.10/32"
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

### 1. ローカルPCからパブリックエンドポイント経由で直接接続できることを確認する

踏み台を経由せず、ローカルから直接`kubectl`を実行します。

```bash
gcloud container clusters get-credentials "$(terraform output -raw cluster_name)" \
  --zone="$(terraform output -raw zone)" --project="$(terraform output -raw project_id)"
kubectl get nodes
```

### 2. 許可していないIPからは到達できないことを確認する（apply成功とは別の確認）

`admin_public_cidr`が正しく機能しているかは、正しいIPで繋がることだけでは確認できません。ドキュメント用の予約アドレス（`203.0.113.1/32`、実在しない想定のIP）を一時的に設定し、接続がタイムアウトすることを確認してから、正しいIPへ戻します。

```bash
terraform apply -var="admin_public_cidr=203.0.113.1/32"
kubectl get nodes --request-timeout=15s   # タイムアウトすること

terraform apply -var="admin_public_cidr=$(curl -4 -s https://ifconfig.me)/32"
kubectl get nodes   # 復帰すること
```

### 3. 踏み台からプライベートエンドポイント経由でも接続できることを確認する

**`--internal-ip`を付けないと、踏み台上でもデフォルトはパブリックエンドポイントになります。** `enable_private_endpoint=false`（Dual Endpoint）の場合、`gcloud container clusters get-credentials`はVPC内から実行してもパブリックエンドポイントのIPをkubeconfigに書き込みます。踏み台のCloud NAT出口IPは`admin_public_cidr`に含まれていないため、`--internal-ip`を省略すると接続がタイムアウトします。

```bash
gcloud compute ssh "$(terraform output -raw bastion_name)" \
  --zone="$(terraform output -raw zone)" --tunnel-through-iap \
  --project="$(terraform output -raw project_id)" \
  --command="gcloud container clusters get-credentials $(terraform output -raw cluster_name) --internal-ip --zone=$(terraform output -raw zone) --project=$(terraform output -raw project_id) && kubectl get nodes"
```

## 削除方法

```bash
terraform destroy
```

**必ず destroy してください。** GKE・踏み台VM・Cloud NATは利用中に料金が発生します。

## 注意点 / 費用

- **`admin_public_cidr`を手元の環境に合わせて必ず指定してください。** デフォルト値はありません（安全側に倒し、誤って全世界に開放する事故を避けるため）
- 手元のグローバルIPが変わった場合（回線切り替え、VPN、ISPの再割当てなど）、`admin_public_cidr`を更新して再applyしないとパブリックエンドポイント経由の接続が失敗します
- `master_authorized_networks_config`を省略すると、パブリックエンドポイントは無制限に公開されます。本サンプルでは必ず設定してください
