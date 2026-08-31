# 07 - Google Kubernetes Engine

最小構成の **Zonal Standard GKE + Spot Node Pool（1ノード）** を Terraform で作成するサンプルです。

## 確認すること

- VPC / Subnet（Pods/Services secondary range 付き）を作成できる
- GKE Cluster と Spot Node Pool を作成できる
- `get-credentials` で接続準備ができる
- Spot Node Pool上にPodを実際にスケジュールできる（Node起動確認とは別）
- `terraform destroy` で削除できる

## 作成されるGCPリソース

| リソース | 内容 |
|---|---|
| `google_project_service` | GKE / Compute API |
| `google_compute_network` / `subnetwork` | 専用 VPC（VPC-native 用 secondary range） |
| `google_container_cluster` | Zonal Standard cluster |
| `google_container_node_pool` | Spot 1ノード |

## 前提条件

- ADC 認証済み
- **課金有効な**検証用 Project
- 十分なクォータ（CPU / IP）

## 必要なAPI

- `container.googleapis.com`
- `compute.googleapis.com`

## 必要な権限（目安）

- Kubernetes Engine Admin
- Compute Network Admin

## ファイル構成

```text
07-gke/
├── README.md
├── docs/
│   ├── PARAMETER.md                  # terraform-docs（自動生成。手動編集しない）
│   ├── GKE-PARAMETERS.md             # クラスタ / ノードプールの詳細対応（手書き）
│   └── RESOURCE-PARAMETERS.md        # ネットワーク等の対応（手書き）
├── DEPENDENCY-GRAPH.svg          # terraform graph（自動生成。手動編集しない）
├── .terraform.lock.hcl
├── versions.tf
├── provider.tf
├── variables.tf
├── network.tf   # VPC / Subnet + secondary ranges（準備）
├── main.tf   # GKE Cluster / Node Pool（本体）
├── outputs.tf
└── terraform.tfvars.example
```

リソースの明示設定と公式ドキュメント上の既定値の対応は `docs/RESOURCE-PARAMETERS.md` と `docs/GKE-PARAMETERS.md` を参照してください。`docs/PARAMETER.md` は terraform-docs の自動生成です。


## 設定方法

```bash
cd Basic-Examples/07-gke
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

作成には数分〜十数分かかることがあります。

## 確認方法

```bash
gcloud container clusters describe "$(terraform output -raw cluster_name)" \
  --zone="$(terraform output -raw cluster_location)"

$(terraform output -raw get_credentials_example)
kubectl get nodes
```

Nodeが `Ready` になっていることは、Clusterが実際にPodを動かせることを保証しない。Spot Node Pool上でPodが起動できるかを別途確認する。

```bash
kubectl run test-pod --image=nginx --restart=Never
kubectl get pod test-pod -o wide --watch   # STATUS が Running になるまで待つ
kubectl delete pod test-pod
```

## 削除方法

```bash
terraform destroy
```

**必ず destroy してください。** 放置するとノード / 制御プレーン関連で継続課金されます。

## 注意点 / 費用

- **コストと作成時間が大きい**ため、本リポジトリでは最後に配置しています
- Spot ノードは回収される可能性があります（学習・短時間検証向け）
- Autopilot ではなく Standard + Spot 1ノードでコストを抑えています
- 本サンプルは公開制御プレーン（private endpoint なし）の最小構成です
- Cloud NAT / Ingress / Workload アプリは含みません
