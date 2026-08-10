# 02 - Network（VPC / Subnet / Firewall）

カスタム VPC、Subnet、Firewall を Terraform で作成するサンプルです。

## 確認すること

- Custom mode VPC（自動サブネットなし）を作成できる
- Region 指定の Subnet を作成できる
- VPC 内通信用 Firewall と IAP SSH 用 Firewall を作成できる
- `terraform destroy` で削除できる

## 作成されるGCPリソース

| リソース | 内容 |
|---|---|
| `google_project_service` | Compute Engine API 有効化（`disable_on_destroy=false`） |
| `google_compute_network` | Custom VPC |
| `google_compute_subnetwork` | Subnet（`asia-northeast1`） |
| `google_compute_firewall` | 内部通信許可 / IAP SSH 許可 |

## 前提条件

- Google Cloud CLI / Terraform がインストール済み
- ADC 認証済み
- 検証用 Project があること

## 必要なAPI

- `compute.googleapis.com`（本サンプル内でも有効化）

## 必要な権限（目安）

- Compute Network Admin 相当（VPC / Subnet / Firewall の作成削除）
- Service Usage Consumer（API 有効化）

## ファイル構成

```text
02-network/
├── README.md
├── versions.tf
├── provider.tf
├── variables.tf
├── network.tf   # VPC / Subnet / Firewall
├── outputs.tf
└── terraform.tfvars.example
```

## 設定方法

```bash
cd Basic-Examples/02-network
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

```bash
gcloud compute networks describe "$(terraform output -raw network_name)" --project="$(grep project_id terraform.tfvars | cut -d'"' -f2)"
gcloud compute networks subnets list --network="$(terraform output -raw network_name)" --project="$(grep project_id terraform.tfvars | cut -d'"' -f2)"
gcloud compute firewall-rules list --filter="network~$(terraform output -raw network_name)" --project="$(grep project_id terraform.tfvars | cut -d'"' -f2)"
```

## 削除方法

```bash
terraform destroy
```

## 注意点 / 費用

- VPC / Firewall 自体の料金は通常発生しません
- Cloud NAT / 外部 IP / VM は本サンプルでは作成しません
- SSH は `0.0.0.0/0` 開放ではなく IAP 向けレンジのみ許可しています
