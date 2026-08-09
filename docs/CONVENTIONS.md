# Repository conventions

このリポジトリでTerraformサンプルを追加する際の基本ルールです。

## 0. 置き場の役割分担

| 置き場 | 役割 |
|---|---|
| `examples/` | 基本。単体・最小構成（1トピック = 1 Root Module） |
| `scenarios/` | 応用。複数サービス連携や実践的な試験コード |
| `modules/` | 共通モジュール。シナリオ間の重複が目立ってから追加する（先に作らない） |

学習・ブログの入口は `examples/`、複合検証は `scenarios/` に置く。

## 1. サンプルは独立したRoot Moduleにする

各 `examples/<番号>-<名前>/` および `scenarios/<番号>-<名前>/` は、可能な限りそのディレクトリだけで検証できる構成にします。

基本ファイル:

```text
README.md
versions.tf
provider.tf
variables.tf
main.tf または data.tf
outputs.tf
terraform.tfvars.example
```

必要に応じてファイルを追加します。

### ファイル分割ルール

- **本体リソース**（例: GCE VM、GKE Cluster）は `main.tf`
- **本体の前提となるネットワーク**（VPC / Subnet / Firewall など）は `network.tf` に分離する
  - 対象例: `examples/04-compute-engine`, `examples/07-gke`
- サンプル自体がネットワーク検証（`examples/02-network`）の場合は、ネットワーク定義を `network.tf` に置く
- 分割は役割が分かる範囲にとどめ、過度に細かくしない

## 2. 検証フロー

原則として以下を確認します。

```bash
terraform init
terraform fmt -check
terraform validate
terraform plan
terraform apply
# GCP側の動作確認
terraform destroy
```

リソースを作成しないサンプルでは `apply` / `destroy` を省略できます。

## 3. Secretをコミットしない

以下はコミットしません。

- `terraform.tfvars`
- `*.tfstate`
- Service Account Key JSON
- Access Token
- Password / API Key / Secret

公開可能な入力例は `terraform.tfvars.example` に記載します。

## 4. ProviderとTerraform Version

各サンプルの `versions.tf` で明示します。

Providerのメジャーバージョンは意図せず更新されないよう制約を設定します。

## 5. 命名

ディレクトリは実行順・記事化の順番を分かりやすくするため、2桁の番号を付与します。

```text
examples/00-provider-check
examples/01-project-service
scenarios/01-gce-iap-vpc
```

Terraform Resource名は、サンプル内で役割が分かる簡潔な名前を使用します。

## 6. READMEに書く内容

各サンプル / シナリオの README には最低限以下を記載します。

- 何を検証するか
- 作成されるGCPリソース
- 前提条件
- 使用方法
- 確認方法
- 削除方法
- 注意点 / 費用

`scenarios/` では特に、関係するサービス一覧とコスト・destroy 手順を明確にする。

## 7. PARAMETER.md / DEPENDENCY-GRAPH.svg

各 root module に次を置く（自動生成。手動編集禁止）。

| ファイル | 生成元 |
|---|---|
| `PARAMETER.md` | `terraform-docs`（設定: `.terraform-docs.yml`） |
| `DEPENDENCY-GRAPH.svg` | `terraform graph` + `dot`（設定: `.terraform-graph.conf`） |

本リポジトリでは **GitHub Actions を使わない**。ローカルで次を実行する。

```bash
./scripts/generate-terraform-docs.sh --all
./scripts/generate-terraform-graphs.sh --all
```

`.tf` 変更後は該当 module、または `--all` で再生成してからコミットする。
