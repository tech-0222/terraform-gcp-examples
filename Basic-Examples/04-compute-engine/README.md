# 04 - Compute Engine

Compute Engine VM（Spot）と、起動に必要な最小ネットワークを Terraform で作成するサンプルです。

## 確認すること

- Spot VM を作成できる
- 外部 IP なし + IAP SSH 用 Firewall で構成できる
- `terraform destroy` で削除できる

## 作成されるGCPリソース

| リソース | 内容 |
|---|---|
| `google_project_service` | Compute Engine API |
| `google_compute_network` / `subnetwork` | 専用 VPC / Subnet |
| `google_compute_firewall` | IAP SSH 許可 |
| `google_compute_instance` | Spot VM（`e2-medium`） |

## 前提条件

- ADC 認証済み
- 検証用 Project があること

## 必要なAPI

- `compute.googleapis.com`

## 必要な権限（目安）

- Compute Admin 相当
- IAP 経由 SSH を試す場合は IAP-secured Tunnel User など

## ファイル構成

```text
04-compute-engine/
├── README.md
├── docs/
│   ├── PARAMETER.md                  # terraform-docs（自動生成。手動編集しない）
│   ├── INSTANCE-PARAMETERS.md        # コンソール / gcloud JSON / Terraform の対応（手書き）
│   └── RESOURCE-PARAMETERS.md        # ネットワークの対応（手書き）
├── DEPENDENCY-GRAPH.svg          # terraform graph（自動生成。手動編集しない）
├── .terraform.lock.hcl
├── versions.tf
├── provider.tf
├── variables.tf
├── network.tf   # VPC / Subnet / Firewall（準備）
├── main.tf   # Compute Engine VM（本体）
├── outputs.tf
└── terraform.tfvars.example
```

コンソール項目と Terraform 属性の対応は `docs/RESOURCE-PARAMETERS.md`（ネットワーク）と `docs/INSTANCE-PARAMETERS.md`（VM）を参照してください。`docs/PARAMETER.md` は Inputs / Outputs の自動生成です。

## 設定方法

```bash
cd Basic-Examples/04-compute-engine
cp terraform.tfvars.example terraform.tfvars
```

```hcl
project_id = "your-project-id"
region     = "asia-northeast1"
zone       = "asia-northeast1-a"
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
  --zone="$(terraform output -raw zone)" \
  --format=json
```

コンソール項目との対応は `docs/INSTANCE-PARAMETERS.md` を参照してください。

IAP SSH 例（権限がある場合）:

```bash
$(terraform output -raw ssh_via_iap_example)
```

## 削除方法

```bash
terraform destroy
```

## 注意点 / 費用

- **Spot VM は予告なく停止・回収される**可能性があります（学習・短時間検証向け）
- VM / ディスク利用中は課金されます。検証後は必ず destroy してください
- 外部 IP / Cloud NAT は作成しません（インターネット向け通信は制限されます）
- OS Login を有効化しています
