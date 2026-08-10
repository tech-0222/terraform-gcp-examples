# 04 - GCS Remote Backend（Terraform State）

Terraform State を **GCS バケット（Object Versioning 有効）** に置くためのブートストラップと、実際に Remote Backend を使う小さな `demo/` をセットにした応用サンプルです。

## 関係するサービス

| サービス | 役割 |
|---|---|
| Cloud Storage | State 保管（versioning） / demo リソース |
| Terraform GCS backend | Remote State + locking |

## 構成

```text
04-gcs-remote-backend/     # ① State 用バケットを作成（local state）
└── demo/                  # ② GCS backend で小さなバケットを作成
```

## 作成されるGCPリソース

| 置き場 | リソース | 内容 |
|---|---|---|
| 親 | `google_storage_bucket.tfstate` | State 用バケット（versioning=true） |
| demo | `google_storage_bucket.demo` | Remote State 管理下のデモ用バケット |

## 前提条件

- ADC 認証済み
- 検証用 Project
- 親モジュールを先に apply 済みであること（demo の backend 先）

## 使用方法

### 1) State バケット（親）

```bash
cd Advanced-Examples/04-gcs-remote-backend
cp terraform.tfvars.example terraform.tfvars
# project_id を設定

terraform init
terraform apply
terraform output state_bucket_name
```

### 2) Remote Backend の demo

```bash
cd demo
cp terraform.tfvars.example terraform.tfvars
cp backend.hcl.example backend.hcl
# backend.hcl の bucket を親の state_bucket_name に書き換え

terraform init -backend-config=backend.hcl
terraform apply
```

State オブジェクト確認:

```bash
gsutil ls -r "gs://$(cd .. && terraform output -raw state_bucket_name)/demo/"
```

### 3) 削除（順序重要）

```bash
# 先に demo（Remote State 側）
cd demo
terraform destroy
# backend 上の state オブジェクトが不要なら（任意）
# gsutil rm -r "gs://<state-bucket>/demo/"

# 親の State バケット
cd ..
terraform destroy
```

## 確認方法

- 親: `gcloud storage buckets describe gs://$(terraform output -raw state_bucket_name)` で versioning が有効
- demo: `terraform state pull` が GCS から読め、`gsutil ls` で `demo/default.tfstate` 相当が見える

## 注意点 / 費用

- State バケットは **本番では force_destroy を慎重に**（本サンプルは学習用に true）
- State には機密が入り得るため、バケット IAM を最小権限に絞る
- 削除は **必ず demo → 親** の順（親を先に消すと demo の state を失う）
- GCS の保存・操作課金は少額ですが、検証後は destroy してください
