# 14 - Cloud KMS

Cloud KMS の KeyRing と対称暗号用 CryptoKey を Terraform で作成する基本サンプルです。

## 確認すること

- Cloud KMS API を有効化できる
- KeyRing を作成できる
- `ENCRYPT_DECRYPT` 用 CryptoKey を作成できる
- Terraform での KMS リソース削除時の挙動を理解する

## 作成されるGCPリソース

| リソース | 内容 |
|---|---|
| `google_project_service` | Cloud KMS API |
| `google_kms_key_ring` | 検証用 KeyRing |
| `google_kms_crypto_key` | 対称暗号用 CryptoKey |

## 重要: 削除について

Cloud KMS は他のサンプルと削除特性が異なります。

Google Provider の `google_kms_key_ring` ドキュメントでは、KeyRing は GCP から削除できず、Terraform の destroy では State から外れても Project 側に残る旨が記載されています。

そのため、このサンプルは **`terraform destroy` で完全に元の状態へ戻るサンプルではありません**。

- 専用の検証 Project で試す
- 同じ Project で再実行するときは `key_ring_name_prefix` を変更する
- KMS の残存リソースを理解したうえで検証する

ことを前提にします。

## 前提条件

- ADC 認証済み
- 検証用 Project

## 必要なAPI

- `cloudkms.googleapis.com`

## 必要な権限（目安）

- Cloud KMS Admin 相当
- Service Usage を操作できる権限

## ファイル構成

```text
14-cloud-kms/
├── README.md
├── versions.tf
├── provider.tf
├── variables.tf
├── main.tf
├── outputs.tf
└── terraform.tfvars.example
```

`PARAMETER.md` / `DEPENDENCY-GRAPH.svg` は実検証時に生成します。

## 設定方法

```bash
cd Basic-Examples/14-cloud-kms
cp terraform.tfvars.example terraform.tfvars
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
gcloud kms keyrings describe "$(terraform output -raw key_ring_name)" \
  --location="$(terraform output -raw location)" \
  --project="$(terraform output -raw project_id)"

gcloud kms keys describe "$(terraform output -raw crypto_key_name)" \
  --keyring="$(terraform output -raw key_ring_name)" \
  --location="$(terraform output -raw location)" \
  --project="$(terraform output -raw project_id)"
```

## 削除方法

```bash
terraform destroy
```

ただし、前述のとおり KMS は完全削除されないリソースがあるため、destroy 後も GCP 側を確認してください。

## 注意点 / 費用

- Key version と暗号処理には料金が発生します
- 実データの暗号化・復号はこの基本サンプルでは行いません
- 本番では Key rotation、IAM、削除防止などを追加で設計してください

## 検証状況

コード準備のみ。`fmt / init / validate / plan / apply / destroy` は未実施です。
