# Scenarios

複数の GCP サービスが絡む応用・試験コードを置く場所です。

## `examples/` との違い

| 置き場 | 役割 |
|---|---|
| `examples/` | 単体・最小の基本コード（1トピック = 1 Root Module） |
| `scenarios/` | 複数サービス連携・より実践的な試験コード |

`examples/` を先に理解してから、こちらに進む想定です。

## 方針

- 各シナリオは独立した Terraform Root Module にする
- `terraform init` → `fmt` → `validate` → `plan` → `apply` → 確認 → `destroy` まで検証できること
- Secret / `terraform.tfvars` / state はコミットしない（`terraform.tfvars.example` を用意する）
- コストと destroy 可否を README に必ず書く
- 共通化（`modules/`）は、シナリオ間で重複が目立ってから検討する（最初から必須にしない）

## ディレクトリ命名

```text
scenarios/
├── README.md
└── <番号>-<短い名前>/
```

例:

```text
01-gce-iap-vpc/
02-cloudrun-artifact-registry/
03-gke-workload-identity-gcs/
```

## 基本ファイル（各シナリオ）

```text
README.md
versions.tf
provider.tf
variables.tf
main.tf
network.tf                 # ネットワーク準備がある場合
outputs.tf
terraform.tfvars.example
```

詳細ルールは `docs/CONVENTIONS.md` を参照してください。

シナリオ追加後は、基本サンプルと同様に次を生成する（GitHub Actions なし・ローカル実行）。

```bash
./scripts/generate-terraform-docs.sh scenarios/<name>
./scripts/generate-terraform-graphs.sh scenarios/<name>
```

## シナリオ一覧

| No. | ディレクトリ | 内容 | 状態 |
|---|---|---|---|
| - | （未作成） | - | 準備中 |

## 候補（未着手）

実装時は上記一覧に追加する。

- GCE + 専用 VPC + IAP SSH
- Cloud Run + Artifact Registry + IAM
- GKE + Workload Identity + Cloud Storage
- GCS Remote Backend（State）の検証
- Workload Identity Federation（GitHub Actions 等）

## 注意

応用シナリオはリソース数・課金が大きくなりやすいです。検証後は必ず `terraform destroy` してください。
