# 10 - Regional External ALB session affinity

同一 NEG 上の 2 VM（backend-a / backend-a2）に対し、Cookie でセッションを固定します。`:82`（1 台）は検証にならないため入れていません。

`08-regional-external-alb-neg` を先に理解してください。state は共有しません。

| ポート | session_affinity | Cookie |
|---|---|---|
| :81 | `GENERATED_COOKIE` | LB が `GCILB=` を発行 |
| :83 | `HTTP_COOKIE` + RING_HASH | アプリが `ROUTE=backend-a` または `backend-a2`（Path=/）。**LB も同名で上書きする** |

ネットワークの正本は 08 の `docs/RESOURCE-PARAMETERS.md` です。

## 確認すること

- `:81` 初回に `Set-Cookie: GCILB=` があり、Cookie 付き 5 回が同じ identity
- `:83` 初回に `ROUTE=` があり、Cookie 付き 5 回が同じ identity
- Cookie なしでは a / a2 が混ざることがある（参考）
- destroy できる

`GCILB` はリージョン外部・内部の Application Load Balancer の名前。グローバルとクラシックは `GCLB`。

**`HTTP_COOKIE` は Cookie の値をハッシュするだけで、値を名前として読まない。** 実測では `ROUTE=backend-a` が `backend-a2` に、`ROUTE=backend-a2` が `backend-a` に向いた（各10回）。アプリ側で行き先を指定したことにはならない。

`http_cookie.name` をアプリと同じ `ROUTE` にしているため、`Set-Cookie` が2つ返り、Cookie ストアには LB の値だけが残る。

[セッションアフィニティは best-effort](https://docs.cloud.google.com/load-balancing/docs/https/request-distribution)で、健全なバックエンドの数が変わらないかぎり、という条件が付く。固定先を UNHEALTHY にすると同じ Cookie が生存側へ流れ、復帰すると元へ戻った（各20回）。

**効いているかは LB のログでもメトリクスでも確かめられない。** `backend_name` はどちらも NEG 名で、VM単位には割れない。アプリの応答かバックエンドのアクセスログで見る。

## 作成される Google Cloud リソース

- Compute API
- カスタム VPC / ワークロード Subnet / **proxy-only Subnet**
- Cloud Router / Cloud NAT
- Health check / proxy-only / IAP SSH 用 Firewall
- バックエンド VM 2 台（同一ゾーン、外部 IP なし、Debian 12、tcp/8080）
- zonal NEG 1 つと Network Endpoint ×2
- Regional Backend Service ×2（GENERATED_COOKIE / HTTP_COOKIE）
- URL map / Target HTTP Proxy / Forwarding Rule ×2（**:81** / **:83**）
- 外部 VIP（PREMIUM）

## 前提条件

- ADC 認証済み
- 課金有効な検証用 Project
- インターネットから VIP:81 / :83 へ到達できること
- `iap_member` に IAP SSH と OS Login を許可する相手（`user:you@example.com` 等）

## ファイル構成

```text
10-regional-alb-session-affinity/
├── README.md
├── docs/
│   ├── PARAMETER.md              # terraform-docs（自動生成。手動編集しない）
│   └── RESOURCE-PARAMETERS.md    # セッション差分（手書き。ネットワーク正本は 08）
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
│   └── startup-cookie.sh.tftpl
└── terraform.tfvars.example
```

リソースの明示設定と公式ドキュメント上の既定値の対応は `docs/RESOURCE-PARAMETERS.md` を参照してください。VPC / proxy-only / NEG は [08 の RESOURCE-PARAMETERS.md](../08-regional-external-alb-neg/docs/RESOURCE-PARAMETERS.md) が正本です。`docs/PARAMETER.md` と `DEPENDENCY-GRAPH.svg` は自動生成です。

## 設定方法

```bash
cd Advanced-Examples/10-regional-alb-session-affinity
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
terraform output -raw curl_generated_cookie
terraform output -raw curl_http_cookie
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
