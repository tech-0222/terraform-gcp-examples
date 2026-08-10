# 03 - GKE + Workload Identity + Cloud Storage

Zonal Spot GKE 上の Pod が **Workload Identity** 経由で GCP SA になりすまし、**GCS へ書き込む**応用サンプルです。

`Basic-Examples/07-gke`（WI 有効化まで）と `03-cloud-storage` を組み合わせ、KSA 注釈・`workloadIdentityUser`・バケット IAM・書き込み Job までを一つの Root Module で扱います。**JSON 鍵は使いません。**

## 関係するサービス

| サービス | 役割 |
|---|---|
| GKE | Spot ノード + Workload Identity |
| IAM | GCP SA / `roles/iam.workloadIdentityUser` |
| Cloud Storage | 書き込み先バケット |
| Kubernetes | Namespace / KSA / Job |

## 作成されるGCP / K8s リソース

| リソース | 内容 |
|---|---|
| `google_project_service` | container / compute / storage / iam |
| `google_compute_network` / `subnetwork` | VPC-native 用 secondary range |
| `google_container_cluster` / `node_pool` | Zonal Standard + Spot 1 ノード |
| `google_service_account` | GCS 書き込み用 GCP SA |
| `google_storage_bucket` (+ IAM) | デモ用バケット |
| `google_service_account_iam_member` | KSA → GCP SA の WI バインド |
| `kubernetes_namespace_v1` / `service_account_v1` / `job_v1` | 書き込み Job（完了待ち） |

## 前提条件

- ADC 認証済み
- **課金有効な**検証用 Project
- 十分なクォータ（CPU / IP）
- ローカルに Terraform / `gcloud`（確認用に `gsutil` / `kubectl` があると便利）

## 必要な権限（目安）

- Kubernetes Engine Admin
- Storage Admin
- Service Account Admin / IAM 変更権限

## ファイル構成

```text
03-gke-workload-identity-gcs/
├── README.md
├── versions.tf
├── provider.tf   # google + kubernetes
├── variables.tf
├── network.tf
├── main.tf       # GKE / GCS / IAM
├── k8s.tf        # Namespace / KSA / Job
├── outputs.tf
└── terraform.tfvars.example
```

## 設定方法

```bash
cd Advanced-Examples/03-gke-workload-identity-gcs
cp terraform.tfvars.example terraform.tfvars
```

```hcl
project_id = "YOUR_PROJECT_ID"
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

GKE 作成に十数分、Job 完了待ちでさらに数分かかることがあります。

## 確認方法

```bash
# クラスタ
gcloud container clusters describe "$(terraform output -raw cluster_name)" \
  --zone="$(terraform output -raw cluster_location)"

# Job が書いたオブジェクト
gsutil cat "gs://$(terraform output -raw bucket_name)/$(terraform output -raw object_name)"

# 任意: Job ログ
$(terraform output -raw get_credentials_example)
kubectl -n "$(terraform output -raw k8s_namespace)" logs job/wi-gcs-write
```

## 削除方法

```bash
terraform destroy
```

バケットは `force_destroy = true` のため、中のオブジェクトも含めて削除されます。

## 注意点 / 費用

- **GKE は高コスト**です。検証後は必ずすぐに `destroy` してください
- Spot ノードは予告なく回収される可能性があります
- apply 中に Job がイメージ pull / WI 伝播待ちで失敗した場合は、数分待って `terraform apply` を再実行してください
- Organization Policy で外部イメージや WI が制限されている場合は設定を合わせてください
