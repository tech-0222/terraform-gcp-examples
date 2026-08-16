# 02 - Cloud Run + Artifact Registry + IAM

Artifact Registry に置くイメージを、専用ランタイム SA 付きの Cloud Run から利用する応用サンプルです。

`Basic-Examples/06-cloud-run`（公開 Hello）と `11-artifact-registry`（リポジトリ単体）を組み合わせ、**リポジトリ IAM・ランタイム SA・認証付き invoker** までを一つの Root Module で扱います。

## 関係するサービス

| サービス | 役割 |
|---|---|
| Artifact Registry | Docker イメージ保管 |
| Cloud Run | コンテナ実行 |
| IAM | AR reader / Run invoker |

## 作成されるGCPリソース

| リソース | 内容 |
|---|---|
| `google_project_service` | run / artifactregistry / iam |
| `google_artifact_registry_repository` | Docker リポジトリ |
| `google_service_account` | Cloud Run ランタイム SA |
| `google_artifact_registry_repository_iam_member` | SA に `artifactregistry.reader` |
| `google_cloud_run_v2_service` | Hello サービス（min 0） |
| `google_cloud_run_v2_service_iam_member` | invoker（ユーザー指定 / 任意で allUsers） |

## 前提条件

- ADC 認証済み
- 検証用 Project があること
- AR へイメージを push する場合は Docker（または同等ツール）と Artifact Registry 認証

## 必要な権限（目安）

- Cloud Run Admin / Artifact Registry Admin / Service Account Admin 相当
- 呼び出し確認を行うユーザーを `invoker_member` に指定

## ファイル構成

```text
02-cloudrun-artifact-registry/
├── README.md
├── docs/RESOURCE-PARAMETERS.md  # コンソール / API / Terraform の対応（手書き）
├── versions.tf
├── provider.tf
├── variables.tf
├── main.tf
├── outputs.tf
└── terraform.tfvars.example
```

リソースの明示設定と公式ドキュメント上の既定値の対応は `docs/RESOURCE-PARAMETERS.md` を参照してください。`PARAMETER.md` は terraform-docs の自動生成です。

## 設定方法

```bash
cd Advanced-Examples/02-cloudrun-artifact-registry
cp terraform.tfvars.example terraform.tfvars
```

```hcl
project_id     = "YOUR_PROJECT_ID"
region         = "asia-northeast1"
invoker_member = "user:you@example.com"
```

## 使用方法

```bash
terraform init
terraform fmt -check
terraform validate
terraform plan
terraform apply
```

初回 apply は公開 Hello イメージでサービスを作成できます。続けて自リポジトリへコピーして切り替える例:

```bash
REPO_URL="$(terraform output -raw repository_url)"
SRC="us-docker.pkg.dev/cloudrun/container/hello"
DST="${REPO_URL}/hello:latest"

gcloud auth configure-docker "${region:-asia-northeast1}-docker.pkg.dev" --quiet
docker pull "${SRC}"
docker tag "${SRC}" "${DST}"
docker push "${DST}"

# tfvars の container_image を DST に更新して再 apply
terraform apply -var="container_image=${DST}"
```

## 確認方法

```bash
gcloud artifacts repositories describe "$(terraform output -raw repository_id)" \
  --location="$(terraform output -raw location)"

gcloud run services describe "$(terraform output -raw service_name)" \
  --region="$(terraform output -raw location)"

# 認証付き呼び出し（invoker_member に自分を入れていること）
eval "$(terraform output -raw curl_authenticated_example)"
```

## 削除方法

```bash
terraform destroy
```

Artifact Registry に残ったイメージもリポジトリ削除時に消えます（destroy 前に手動削除してもよいです）。

## 注意点 / 費用

- Cloud Run はリクエスト課金（min instance 0）。検証後は `destroy`
- Artifact Registry は保存容量に応じて課金
- 既定では **公開 invoker（allUsers）を付けません**。学習で公開したい場合のみ `allow_unauthenticated = true`
- Organization Policy で `allUsers` や外部イメージが制限されている場合は設定を合わせてください
