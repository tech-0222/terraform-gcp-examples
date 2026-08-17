# 09 - Regional External ALB + Cloud Armor

`08-regional-external-alb-neg` と同型の Regional External ALB に、**リージョナル Cloud Armor** を付けます。許可した送信元 IP だけ 200、それ以外は **403** です。

ネットワーク項目の正本は 08 の `docs/RESOURCE-PARAMETERS.md` です。ここでは Armor の差分だけ書きます。state は共有しません。

## 確認すること

- 許可リストの IP から `http://VIP/` が 200 / `backend-a`
- 許可リスト外から 403（バックエンドへ到達しない）
- 同一 VPC から `:8080` 直叩きは Armor の対象外
- destroy できる

## 作成される Google Cloud リソース

- Compute API
- カスタム VPC / ワークロード Subnet / **proxy-only Subnet**
- Cloud Router / Cloud NAT
- Health check / proxy-only / IAP SSH 用 Firewall
- バックエンド VM 1 台（外部 IP なし、Debian 12、tcp/8080）
- zonal NEG と Network Endpoint
- Regional Backend Service（Cloud Armor 紐付け）/ URL map / Target HTTP Proxy / Forwarding Rule（**tcp/80**）
- リージョナル Cloud Armor（許可 IP 以外 403）
- 外部 VIP（PREMIUM）
- 任意: 拒否確認用クライアント VM（`create_deny_client = true`）

## 前提条件

- ADC 認証済み
- 課金有効な検証用 Project
- `allowed_src_ips` に自分のグローバル IPv4 を `/32` で入れる（空のまま apply しない）

## ファイル構成

```text
09-regional-alb-cloud-armor/
├── README.md
├── docs/
│   ├── PARAMETER.md              # terraform-docs（自動生成。手動編集しない）
│   └── RESOURCE-PARAMETERS.md    # Armor 差分（手書き。ネットワーク正本は 08）
├── DEPENDENCY-GRAPH.svg          # terraform graph（自動生成。手動編集しない）
├── .terraform.lock.hcl
├── versions.tf
├── provider.tf
├── variables.tf
├── network.tf
├── main.tf
├── outputs.tf
├── scripts/
│   └── startup-a.sh
└── terraform.tfvars.example
```

リソースの明示設定と公式ドキュメント上の既定値の対応は `docs/RESOURCE-PARAMETERS.md` を参照してください。VPC / proxy-only / NEG は [08 の RESOURCE-PARAMETERS.md](../08-regional-external-alb-neg/docs/RESOURCE-PARAMETERS.md) が正本です。`docs/PARAMETER.md` と `DEPENDENCY-GRAPH.svg` は自動生成です。

## 設定方法

```bash
cd Advanced-Examples/09-regional-alb-cloud-armor
cp terraform.tfvars.example terraform.tfvars
# project_id と allowed_src_ips を設定
```

## 使用方法

```bash
terraform init
terraform fmt -check
terraform validate
terraform plan
terraform apply
curl -si "http://$(terraform output -raw vip)/"
```

任意で `create_deny_client = true` にすると、エフェメラル外部 IP の VM から VIP を叩いて 403 を確認できます。

## 削除方法

```bash
terraform destroy
```

Backend Service がポリシーを参照したままだとポリシー削除に失敗することがあります。その場合は BS から security policy を外してから destroy するか、もう一度 apply / destroy します。コード側は `lifecycle { create_before_destroy = true }` をポリシーに付けています。

**必ず destroy してください。** 外部 VIP・NAT・VM は課金されます。
