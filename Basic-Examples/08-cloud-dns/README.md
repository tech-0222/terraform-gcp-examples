# 08 - Cloud DNS

Private Cloud DNS Zone と A Record を Terraform で作成・確認・削除する最小サンプルです。VM を2台作成し、Private Zone に紐づく VPC からは名前解決できること、紐づかない別 VPC やインターネット経由では解決できないことを実際に確認します。

Public DNS はドメイン取得や NS 委譲が必要になるため、この基本サンプルでは専用 VPC に紐づく Private DNS を扱います。

## 確認すること

- Cloud DNS API / Compute Engine API を有効化できる
- Custom mode VPC を作成できる
- VPC から参照できる Private Managed Zone を作成できる
- Private Zone に A Record を作成できる
- **Private Zoneに紐づいたVPC内のVMからは名前解決できる**
- **紐づかない別VPCのVMからは名前解決できない**（Instanceの状態確認とは別）
- **インターネット経由（手元の端末）でも名前解決できない**
- `terraform destroy` で削除できる

## 作成されるGCPリソース

| リソース | 内容 |
|---|---|
| `google_project_service` | Cloud DNS / Compute Engine API |
| `google_compute_network` | Private DNSの参照元となる専用VPCと、紐づかない別VPC（2つ） |
| `google_compute_subnetwork` | 各VPCのSubnet（2つ） |
| `google_compute_firewall` | IAP SSH許可（2つ） |
| `google_dns_managed_zone` | Private Managed Zone |
| `google_dns_record_set` | 検証用 A Record |
| `google_compute_instance` | 検証用VM（Private Zoneに紐づくVPC / 紐づかない別VPCに各1台） |

## 前提条件

- Google Cloud CLI / Terraform がインストール済み
- ADC 認証済み
- 検証用 Project があること

## 必要なAPI

- `dns.googleapis.com`
- `compute.googleapis.com`

## 必要な権限（目安）

- DNS Administrator 相当
- Compute Network Admin 相当
- Compute Instance Admin 相当
- IAP-secured Tunnel User（VMへのSSHに必要）
- Service Usage Consumer

## ファイル構成

```text
08-cloud-dns/
├── README.md
├── docs/
│   ├── PARAMETER.md                  # terraform-docs（自動生成。手動編集しない）
│   └── RESOURCE-PARAMETERS.md        # コンソール / API / Terraform の対応（手書き）
├── DEPENDENCY-GRAPH.svg          # terraform graph（自動生成。手動編集しない）
├── .terraform.lock.hcl
├── versions.tf
├── provider.tf
├── variables.tf
├── network.tf   # VPC×2 / Subnet / Firewall（準備）
├── main.tf   # DNS Zone / Record / 検証用VM×2（本体）
├── outputs.tf
└── terraform.tfvars.example
```

リソースの明示設定と公式ドキュメント上の既定値の対応は `docs/RESOURCE-PARAMETERS.md` を参照してください。`docs/PARAMETER.md` は terraform-docs の自動生成です。


## 設定方法

```bash
cd Basic-Examples/08-cloud-dns
cp terraform.tfvars.example terraform.tfvars
```


```hcl
project_id = "your-project-id"
region     = "asia-northeast1"
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

Managed Zone:

```bash
gcloud dns managed-zones describe "$(terraform output -raw managed_zone_name)" \
  --project="$(grep project_id terraform.tfvars | cut -d'"' -f2)"
```

Record:

```bash
gcloud dns record-sets list \
  --zone="$(terraform output -raw managed_zone_name)" \
  --name="$(terraform output -raw record_fqdn)" \
  --project="$(grep project_id terraform.tfvars | cut -d'"' -f2)"
```

ManagedZoneとRecordが存在することは、実際に名前解決できることを意味しない。3つの経路で実際に確認する。

**1. Private Zoneに紐づいたVPC内のVMから（解決できるはず）**

```bash
gcloud compute ssh "$(terraform output -raw vm_in_zone_name)" \
  --zone="$(terraform output -raw zone)" \
  --tunnel-through-iap \
  --project="$(grep project_id terraform.tfvars | cut -d'"' -f2)" \
  --command="getent hosts $(terraform output -raw record_fqdn)"
```

**2. 紐づかない別VPCのVMから（解決できないはず）**

```bash
gcloud compute ssh "$(terraform output -raw vm_outside_zone_name)" \
  --zone="$(terraform output -raw zone)" \
  --tunnel-through-iap \
  --project="$(grep project_id terraform.tfvars | cut -d'"' -f2)" \
  --command="getent hosts $(terraform output -raw record_fqdn)"
```

**3. 手元の端末から（インターネット経由。解決できないはず）**

```bash
getent hosts "$(terraform output -raw record_fqdn)"
```

`getent`は見つからない場合、出力なしで終了コード`2`を返す。「解決できない」ことの確認が重要。Private Zoneを使う理由がそこにあるため。

## 削除方法

```bash
terraform destroy
```

**必ず destroy してください。** VMが2台起動したままだと課金が続きます。

## 注意点 / 費用

- Cloud DNS の Managed Zone / Query は料金が発生する可能性があります
- 検証用VM（Spot、外部IPなし）2台が課金対象です。短時間で destroy すれば数円程度の見込みです
- Public Zone / ドメイン取得 / NS 委譲は本サンプルの対象外です

## 検証状況

実GCP環境（`tech-0222-tf-examples`）で `fmt / init / validate / plan / apply` を実施し、以下を確認しました。

- Private Zoneに紐づいたVPC内のVMから`getent hosts`で名前解決できること
- 紐づかない別VPCのVMからは解決できないこと（`getent`終了コード2）
- 手元の端末（インターネット経由）からも解決できないこと（`getent`終了コード2）

確認後、`terraform destroy`まで完了しています。
