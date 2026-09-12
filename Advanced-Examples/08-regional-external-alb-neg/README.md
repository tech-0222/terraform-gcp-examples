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
- `iap_member` に IAP SSH と OS Login を許可する相手（`user:you@example.com` 等）

## ファイル構成

```text
08-regional-external-alb-neg/
├── README.md
├── docs/
│   ├── PARAMETER.md              # terraform-docs（自動生成。手動編集しない）
│   └── RESOURCE-PARAMETERS.md    # コンソール / API / Terraform の対応（手書き）
├── DEPENDENCY-GRAPH.svg          # terraform graph（自動生成。手動編集しない）
├── .terraform.lock.hcl
├── versions.tf
├── provider.tf
├── variables.tf
├── network.tf
├── main.tf
├── iam.tf                        # IAP SSH / OS Login の IAM
├── outputs.tf
├── scripts/
│   ├── startup-a.sh
│   ├── startup-a2.sh
│   └── startup-b.sh
└── terraform.tfvars.example
```

リソースの明示設定と公式ドキュメント上の既定値の対応は `docs/RESOURCE-PARAMETERS.md` を参照してください。`docs/PARAMETER.md` と `DEPENDENCY-GRAPH.svg` は自動生成です。

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

## SSH（OS Login）

VM は `enable-oslogin = "TRUE"` で作ります。IAP 経由で入ります。

```bash
gcloud compute ssh <インスタンス名> --zone=<ゾーン> --tunnel-through-iap
```

OS Login にしている理由は、**プロジェクトのメタデータに SSH 公開鍵が残らない**ためです。OS Login を使わない場合、`gcloud compute ssh` の初回に公開鍵が `ssh-keys` メタデータへ自動登録され、組織の機密アクション通知（`add_ssh_key`）が飛びます。`terraform destroy` はメタデータに触らないので、鍵はそのまま残ります。

実測（`gcloud compute project-info describe` のメタデータを ssh の前後で比較）。

| 項目 | 結果 |
|---|---|
| メタデータの `ssh-keys` | ssh 前後で **sha256 が変わらない** |
| VM 上のユーザー名 | `you_example_com` 形式（ホームも同名。`/home/<ローカル名>` を決め打ちしたスクリプトは壊れる） |
| `~/.ssh/authorized_keys` | 存在しない（[OS Login 有効時は削除される](https://docs.cloud.google.com/compute/docs/oslogin/set-up-oslogin)） |

付与しているのは `roles/compute.osAdminLogin` です。`roles/compute.osLogin` は「standard (non-administrator) user」で **`sudo` が通りません**。確認手順に `sudo` があるため管理者側を付けています。プロジェクトのオーナーは `compute.instances.osAdminLogin` を含むので、オーナーで試すとこの違いに気づけません。

## 削除方法

```bash
terraform destroy
```

**必ず destroy してください。** 外部 VIP・NAT・VM は課金されます。

## 注意点 / 費用

- バックエンドはヘルスチェック安定のため **Spot にしていません**
- クライアントから見える送信元はインターネット IP ですが、VM から見た送信元は **proxy-only subnet** です
