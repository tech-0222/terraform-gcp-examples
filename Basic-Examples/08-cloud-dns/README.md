# 08 - Cloud DNS

Private Cloud DNS Zone と A Record を Terraform で作成・確認・削除する最小サンプルです。

Public DNS はドメイン取得や NS 委譲が必要になるため、この基本サンプルでは専用 VPC に紐づく Private DNS を扱います。

## 確認すること

- Cloud DNS API / Compute Engine API を有効化できる
- Custom mode VPC を作成できる
- VPC から参照できる Private Managed Zone を作成できる
- Private Zone に A Record を作成できる
- `terraform destroy` で削除できる

## 作成されるGCPリソース

| リソース | 内容 |
|---|---|
| `google_project_service` | Cloud DNS / Compute Engine API |
| `google_compute_network` | Private DNS の参照元となる専用 VPC |
| `google_dns_managed_zone` | Private Managed Zone |
| `google_dns_record_set` | 検証用 A Record |

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
- Service Usage Consumer

## ファイル構成

```text
08-cloud-dns/
├── README.md
├── docs/RESOURCE-PARAMETERS.md  # コンソール / API / Terraform の対応（手書き）
├── versions.tf
├── provider.tf
├── variables.tf
├── network.tf   # VPC（Private Zone 用の準備）
├── main.tf      # DNS Zone / Record（本体）
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

Private DNS の実際の名前解決は、対象 VPC に接続された VM などから確認します。本サンプルでは VM は作成しません。

## 削除方法

```bash
terraform destroy
```

## 注意点 / 費用

- Cloud DNS の Managed Zone / Query は料金が発生する可能性があります
- Public Zone / ドメイン取得 / NS 委譲は本サンプルの対象外です
- A Record の IP は説明用の Private IP であり、実体の VM は作成しません
