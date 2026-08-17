# 01 - GCE + VPC + IAP SSH

専用 VPC 上の **外部 IP なし Spot VM** に対し、**IAP TCP forwarding + OS Login + IAM** まで含めて接続できるようにする応用サンプルです。

`Basic-Examples/04-compute-engine` が「IAP 用 Firewall + 外部 IP なし」までなのに対し、本シナリオは接続に必要な **IAP / OS Login の IAM** と **VM 用 Service Account** まで Terraform で揃えます。

## 関係するサービス

| サービス | 役割 |
|---|---|
| Compute Engine | Spot VM / VPC / Firewall |
| Identity-Aware Proxy | SSH 用 TCP forwarding |
| OS Login | SSH 鍵の自動管理 |
| IAM | tunnel / OS Login 権限付与 |

## 作成されるGCPリソース

| リソース | 内容 |
|---|---|
| `google_project_service` | compute / iap / iam / oslogin |
| `google_compute_network` / `subnetwork` | 専用 VPC / Subnet（Private Google Access） |
| `google_compute_firewall` | IAP 範囲 `35.235.240.0/20` → TCP/22 |
| `google_service_account` | VM ランタイム SA |
| `google_compute_instance` | Spot VM（外部 IP なし） |
| `google_project_iam_member` | `iap.tunnelResourceAccessor` / `compute.osLogin` |
| `google_iap_tunnel_instance_iam_member` | インスタンス単位の IAP 許可 |

## 前提条件

- ADC 認証済み
- 検証用 Project があること
- `iap_member` に指定する Google アカウントで `gcloud` にログインしていること（接続確認時）

## 必要な権限（目安）

- Project Editor 相当（または Compute / IAM / Service Usage の作成権限）
- 接続確認を行うユーザー自身が `iap_member` であること

## ファイル構成

```text
01-gce-iap-vpc/
├── README.md
├── docs/
│   ├── PARAMETER.md                  # terraform-docs（自動生成。手動編集しない）
│   └── RESOURCE-PARAMETERS.md        # コンソール / API / Terraform の対応（手書き）
├── DEPENDENCY-GRAPH.svg          # terraform graph（自動生成。手動編集しない）
├── .terraform.lock.hcl
├── versions.tf
├── provider.tf
├── variables.tf
├── network.tf   # VPC / Subnet / Firewall
├── main.tf   # API / SA / VM / IAM
├── outputs.tf
└── terraform.tfvars.example
```

リソースの明示設定と公式ドキュメント上の既定値の対応は `docs/RESOURCE-PARAMETERS.md` を参照してください。`docs/PARAMETER.md` は terraform-docs の自動生成です。

## 設定方法

```bash
cd Advanced-Examples/01-gce-iap-vpc
cp terraform.tfvars.example terraform.tfvars
```

```hcl
project_id = "tech-0222-tf-examples"
region     = "asia-northeast1"
zone       = "asia-northeast1-a"
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

```bash
gcloud compute instances describe "$(terraform output -raw instance_name)" \
  --zone="$(terraform output -raw zone)"
```

IAP SSH（対話なしの疎通確認）:

```bash
gcloud compute ssh "$(terraform output -raw instance_name)" \
  --zone="$(terraform output -raw zone)" \
  --tunnel-through-iap \
  --command='hostname && whoami'
```

または:

```bash
$(terraform output -raw ssh_via_iap_example) --command='echo ok'
```

## 削除方法

```bash
terraform destroy
```

## 注意点 / 費用

- **Spot VM は予告なく停止・回収**される可能性があります（短時間検証向け）
- VM / ディスク利用中は課金されます。検証後は必ず `destroy` してください
- 外部 IP / Cloud NAT は作りません（インターネット向け通信は制限されます）
- Organization Policy で IAP / OS Login / 外部 IP が制限されている場合は失敗します
- `iap_member` の project IAM は destroy 時に削除されます（既存の同ロール手動付与と共存する場合は注意）
