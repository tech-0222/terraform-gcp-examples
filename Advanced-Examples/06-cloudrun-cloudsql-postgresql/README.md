# 06 - Cloud Run + Cloud SQL for PostgreSQL + Secret Manager

Cloud Run から Cloud SQL for PostgreSQL へ接続し、DB Password を Secret Manager から安全に注入する応用サンプルです。

`Basic-Examples/06-cloud-run`、`09-secret-manager`、`13-cloud-sql-postgresql` の内容を組み合わせ、**Cloud Run Runtime SA / Cloud SQL Client IAM / Secret Manager IAM / Unix socket 接続**までを一つの Root Module で扱います。

## 構成

```text
Client
  |
  v
Cloud Run
  |  Runtime SA
  |  ├─ roles/cloudsql.client
  |  └─ roles/secretmanager.secretAccessor
  |
  +---- Secret Manager
  |       └─ DB_PASSWORD
  |
  +---- /cloudsql/<connection-name>
          |
          v
       Cloud SQL
       PostgreSQL
```

接続確認用として `app/` に小さな Python アプリも同梱します。

## 関係するサービス

| サービス | 役割 |
|---|---|
| Cloud Run | 接続確認アプリの実行 |
| Cloud SQL for PostgreSQL | アプリDB |
| Secret Manager | DB Password 保管 |
| IAM | Cloud SQL Client / Secret Accessor / Run invoker |
| Artifact Registry | 接続確認アプリのDockerイメージ保管 |

## 作成されるGCPリソース

| リソース | 内容 |
|---|---|
| `google_project_service` | run / sqladmin / secretmanager / artifactregistry / iam |
| `google_artifact_registry_repository` | サンプルアプリ用 Docker repository |
| `google_sql_database_instance` | PostgreSQL 15 / Zonal / `db-f1-micro` |
| `google_sql_database` | `appdb` |
| `google_sql_user` | `appuser`（write-only password） |
| `google_secret_manager_secret` | DB Password 用 Secret |
| `google_secret_manager_secret_version` | DB Password（write-only data） |
| `google_service_account` | Cloud Run Runtime SA |
| IAM resources | Cloud SQL Client / Secret Accessor / AR reader / Run invoker |
| `google_cloud_run_v2_service` | Cloud SQL Unix socket をマウントした Cloud Run |

## Secret の扱い

このシナリオは Terraform **1.11+** の write-only argument を使用します。

- `google_sql_user.password_wo`
- `google_secret_manager_secret_version.secret_data_wo`

これにより DB Password 自体を Terraform の raw plan / state に保存しない構成にします。

ただし、入力元のローカル `terraform.tfvars` には値が存在するため、**`terraform.tfvars` は絶対にコミットしない**でください。

Password を変更するときは `db_password` と同時に `db_password_version` を増やします。

## Cloud SQL 接続方式

Cloud SQL は Public IPv4 を有効化しますが、Cloud Run からは直接IP接続せず、Cloud SQL integration が提供する Unix socket を使用します。

```text
/cloudsql/<PROJECT_ID>:<REGION>:<INSTANCE_NAME>
```

Cloud Run Runtime SA には `roles/cloudsql.client` を付与します。

`authorized_networks` は設定しません。

## 前提条件

- ADC 認証済み
- 課金が有効な検証用 Project
- Terraform 1.11+
- Google Cloud CLI
- 接続確認アプリを利用する場合は Docker（または互換ツール）

## 必要な権限（目安）

Terraform 実行者:

- Cloud Run Admin
- Cloud SQL Admin
- Secret Manager Admin
- Artifact Registry Admin
- Service Account Admin
- Project IAM Admin 相当
- Service Usage を操作できる権限

## ファイル構成

```text
06-cloudrun-cloudsql-postgresql/
├── README.md
├── docs/
│   ├── PARAMETER.md              # terraform-docs（自動生成。手動編集しない）
│   └── RESOURCE-PARAMETERS.md    # コンソール / API / Terraform の対応（手書き）
├── DEPENDENCY-GRAPH.svg          # terraform graph（自動生成。手動編集しない）
├── .terraform.lock.hcl
├── versions.tf
├── provider.tf
├── variables.tf
├── main.tf
├── iam.tf
├── secret.tf
├── outputs.tf
├── terraform.tfvars.example
└── app/
    ├── Dockerfile
    ├── .dockerignore
    ├── requirements.txt
    └── app.py
```

リソースの明示設定と公式ドキュメント上の既定値の対応は `docs/RESOURCE-PARAMETERS.md` を参照してください。`docs/PARAMETER.md` は terraform-docs の自動生成です。


## 1. 設定

```bash
cd Advanced-Examples/06-cloudrun-cloudsql-postgresql
cp terraform.tfvars.example terraform.tfvars
```

最低限、次を変更します。

```hcl
project_id = "your-project-id"

db_password         = "replace-with-a-strong-test-password"
db_password_version = 1

invoker_member = "user:you@example.com"
```

## 2. 初回 apply

初回はデフォルトの公開 Hello イメージを利用します。

```bash
terraform init
terraform fmt -check
terraform validate
terraform plan
terraform apply
```

この段階で以下が作成されます。

- Artifact Registry
- Cloud SQL / Database / User
- Secret Manager
- Runtime SA / IAM
- Cloud Run
- Cloud SQL Unix socket mount
- Secret Manager → `DB_PASSWORD` 環境変数

Hello イメージ自体はDB接続処理を持たないため、次の手順で同梱アプリへ切り替えます。

## 3. 接続確認アプリを build / push

```bash
REGION="$(terraform output -raw location)"
REPO_URL="$(terraform output -raw repository_url)"
APP_IMAGE="$(terraform output -raw app_image_example)"

gcloud auth configure-docker "${REGION}-docker.pkg.dev" --quiet

docker build -t "${APP_IMAGE}" ./app
docker push "${APP_IMAGE}"
```

## 4. Cloud Run を接続確認アプリへ切り替える

```bash
terraform apply -var="container_image=${APP_IMAGE}"
```

## 5. 確認

Cloud SQL:

```bash
gcloud sql instances describe "$(terraform output -raw sql_instance_name)" \
  --project="$(terraform output -raw project_id)"
```

Cloud Run:

```bash
gcloud run services describe "$(terraform output -raw service_name)" \
  --region="$(terraform output -raw location)" \
  --project="$(terraform output -raw project_id)"
```

DB接続:

```bash
eval "$(terraform output -raw curl_authenticated_example)"
```

成功例:

```json
{
  "connection": "cloud-sql-unix-socket",
  "database": "appdb",
  "status": "ok",
  "user": "appuser"
}
```

ヘルスチェック:

```bash
curl -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
  "$(terraform output -raw service_url)/health"
```

**パス名に`healthz`を使わない。** Cloud Runのデフォルトドメイン（`*.run.app`）では`/healthz`が予約パス扱いで、Google Frontendの段階でコンテナに到達せず404になる（`/health`など他のパスは到達する）。過去このアプリは`/healthz`を使っていたため、実際には呼び出せないエンドポイントだった。

## 6. Password rotation

`terraform.tfvars` の値を変更し、versionを増やします。

```hcl
db_password         = "new-test-password"
db_password_version = 2
```

その後:

```bash
terraform apply
```

## 7. 削除

```bash
terraform destroy
```

Artifact Registry に push した接続確認用イメージも repository 削除時に削除されます。

## 注意点 / 費用

- **Cloud SQL は継続課金されるため、検証後は必ず destroy してください**
- Cloud Run は min instance 0
- Cloud SQL は学習用に `deletion_protection = false` / backup disabled
- Public IPv4 は有効ですが、Cloud Run は Unix socket + Cloud SQL Auth Proxy 経路を使用します
- 公開 invoker (`allUsers`) はデフォルト無効です
- 本番では HA、backup、PITR、private IP、connection pooling、Secret rotation、State backend/IAM などを別途設計してください
- write-only argument を使っても、Terraform State 自体の保護が不要になるわけではありません

## 検証状況

実GCP環境（`YOUR_PROJECT_ID`）で `fmt / init / validate / plan / apply` を実施し、接続確認アプリを Artifact Registry へ push 後に Cloud Run イメージを差し替え、認証付き curl で `status=ok` / `database=appdb` / `user=appuser` / `connection=cloud-sql-unix-socket` を確認しました。`terraform destroy` まで完了しています。

