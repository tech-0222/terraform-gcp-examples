# 08 - Regional External Application Load Balancer + zonal NEG

インターネット向けの **Regional External Application Load Balancer**（`EXTERNAL_MANAGED` / Envoy）を、**zonal NEG（`GCE_VM_IP_PORT`）** に載せる応用サンプルです。

同一 VIP の **:81 → bs-a（zone_a の 2 VM）**、**:82 → bs-b（zone_c の 1 VM）** で入口を分けます。パス振り分けではありません。

`09-regional-alb-cloud-armor` / `10-regional-alb-session-affinity` を読む前に、本サンプルを理解してください。state は共有しません。

## 確認すること

- proxy-only subnet（`REGIONAL_MANAGED_PROXY`）が作られる
- `http://VIP:81/` が `backend-a` または `backend-a2` を返す
- `http://VIP:82/` が `backend-b` を返す
- destroy できる

## 作成される Google Cloud リソース

- Compute API
- カスタム VPC / ワークロード Subnet / **proxy-only Subnet**
- Cloud Router / Cloud NAT（アウトバウンドのみ。ALB のインバウンド経路ではない）
- Health check / proxy-only / IAP SSH 用 Firewall
- バックエンド VM 3 台（外部 IP なし、Debian 12、tcp/8080）
- zonal NEG 2 つと Network Endpoint
- Regional Backend Service / URL map / Target HTTP Proxy / Forwarding Rule ×2
- 外部 VIP（PREMIUM）

## 前提条件

- ADC 認証済み
- 課金有効な検証用 Project
- インターネットから VIP:81 / :82 へ到達できること（自宅 FW で非標準ポートを塞いでいる場合は失敗する）

## ファイル構成

```text
08-regional-external-alb-neg/
├── README.md
├── RESOURCE-PARAMETERS.md
├── versions.tf
├── provider.tf
├── variables.tf
├── network.tf
├── main.tf
├── outputs.tf
├── scripts/
│   ├── startup-a.sh
│   ├── startup-a2.sh
│   └── startup-b.sh
└── terraform.tfvars.example
```

`PARAMETER.md` は terraform-docs の自動生成です。

## 設定方法

```bash
cd Advanced-Examples/08-regional-external-alb-neg
cp terraform.tfvars.example terraform.tfvars
# project_id を設定
```

## 使用方法

```bash
terraform init
terraform fmt -check
terraform validate
terraform plan
terraform apply
```

```bash
curl -sS "http://$(terraform output -raw vip):81/"
curl -sS "http://$(terraform output -raw vip):82/"
```

## 削除方法

```bash
terraform destroy
```

**必ず destroy してください。** 外部 VIP・NAT・VM は課金されます。

## 注意点 / 費用

- バックエンドはヘルスチェック安定のため **Spot にしていません**
- クライアントから見える送信元はインターネット IP ですが、VM から見た送信元は **proxy-only subnet** です
