# Advanced-Examples

複数の GCP サービスが絡む応用・試験コードを置く場所です。

## `Basic-Examples/` との違い

| 置き場 | 役割 |
|---|---|
| `Basic-Examples/` | 単体・最小の基本コード（1トピック = 1 Root Module） |
| `Advanced-Examples/` | 複数サービス連携・より実践的な試験コード |

`Basic-Examples/` を先に理解してから、こちらに進む想定です。

## 方針

- 各シナリオは独立した Terraform Root Module にする
- `terraform init` → `fmt` → `validate` → `plan` → `apply` → 確認 → `destroy` まで検証できること
- Secret / `terraform.tfvars` / state はコミットしない（`terraform.tfvars.example` を用意する）
- コストと destroy 可否を README に必ず書く
- 共通化（`modules/`）は、シナリオ間で重複が目立ってから検討する（最初から必須にしない）

## ディレクトリ命名

```text
Advanced-Examples/
├── README.md
└── <番号>-<短い名前>/
```

例:

```text
01-gce-iap-vpc/
02-cloudrun-artifact-registry/
03-gke-workload-identity-gcs/
04-gcs-remote-backend/
05-wif-github-actions/
06-cloudrun-cloudsql-postgresql/
07-iap-ssh-port-forwarding/
08-regional-external-alb-neg/
09-regional-alb-cloud-armor/
10-regional-alb-session-affinity/
```

## 基本ファイル（各シナリオ）

```text
README.md
docs/RESOURCE-PARAMETERS.md     # コンソール / API / Terraform の対応（手書き）
versions.tf
provider.tf
variables.tf
main.tf
network.tf                 # ネットワーク準備がある場合
outputs.tf
terraform.tfvars.example
```

詳細ルールは `docs/CONVENTIONS.md` を参照してください。

シナリオ追加後は、基本サンプルと同様に次を生成する（**ドキュメント生成用の GitHub Actions は使わない**。ローカル実行）。WIF デモ用 workflow は `.github/workflows/wif-demo.yml` を参照。手書きの `docs/RESOURCE-PARAMETERS.md` も更新する。

```bash
./scripts/generate-terraform-docs.sh Advanced-Examples/<name>
./scripts/generate-terraform-graphs.sh Advanced-Examples/<name>
```

## シナリオ一覧

| No. | ディレクトリ | 内容 | 状態 |
|---|---|---|---|
| 01 | `01-gce-iap-vpc` | GCE Spot + 専用 VPC + IAP SSH / OS Login IAM | 実装済み |
| 02 | `02-cloudrun-artifact-registry` | Cloud Run + Artifact Registry + ランタイム SA / invoker IAM | 実装済み |
| 03 | `03-gke-workload-identity-gcs` | GKE Spot + Workload Identity + GCS 書き込み | 実装済み |
| 04 | `04-gcs-remote-backend` | GCS Remote Backend（State）+ demo | 実装済み |
| 05 | `05-wif-github-actions` | Workload Identity Federation（GitHub Actions OIDC） | 実装済み |
| 06 | `06-cloudrun-cloudsql-postgresql` | Cloud Run + Cloud SQL PostgreSQL + Secret Manager | 実装済み |
| 07 | `07-iap-ssh-port-forwarding` | IAP SSH + Local Port Forwarding + 非公開 nginx | 実装済み |
| 08 | `08-regional-external-alb-neg` | Regional External ALB + zonal NEG（:81 / :82） | 実装済み |
| 09 | `09-regional-alb-cloud-armor` | Regional External ALB + Cloud Armor（許可 IP 以外 403） | 実装済み |
| 10 | `10-regional-alb-session-affinity` | Regional External ALB セッション（GENERATED_COOKIE / HTTP_COOKIE） | 実装済み |

## 候補（未着手）

（なし）

## 注意

応用シナリオはリソース数・課金が大きくなりやすいです。検証後は必ず `terraform destroy` してください。
