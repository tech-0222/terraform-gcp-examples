# Repository conventions

このリポジトリでTerraformサンプルを追加する際の基本ルールです。

## 0. 置き場の役割分担

| 置き場 | 役割 |
|---|---|
| `Basic-Examples/` | 基本。単体・最小構成（1トピック = 1 Root Module） |
| `Advanced-Examples/` | 応用。複数サービス連携や実践的な試験コード |
| `modules/` | 共通モジュール。シナリオ間の重複が目立ってから追加する（先に作らない） |

学習・ブログの入口は `Basic-Examples/`、複合検証は `Advanced-Examples/` に置く。

## 1. サンプルは独立したRoot Moduleにする

各 `Basic-Examples/<番号>-<名前>/` および `Advanced-Examples/<番号>-<名前>/` は、可能な限りそのディレクトリだけで検証できる構成にします。

基本ファイル:

```text
README.md
docs/
  PARAMETER.md               # terraform-docs。自動生成。手動編集禁止
  RESOURCE-PARAMETERS.md     # 手書き
DEPENDENCY-GRAPH.svg         # terraform graph。自動生成。手動編集禁止
.terraform.lock.hcl
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
  - 対象例: `Basic-Examples/04-compute-engine`, `Basic-Examples/07-gke`
- サンプル自体がネットワーク検証（`Basic-Examples/02-network`）の場合は、ネットワーク定義を `network.tf` に置く
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
# Cloud Logging の確認（下記「2-1」）
terraform destroy
```

リソースを作成しないサンプルでは `apply` / `destroy` を省略できます。

### 2-1. Cloud Logging を必ず確認する

**GCPリソースを作成する検証では、毎回 `gcloud logging read` でログを確認します。** `kubectl describe` や `gcloud ... operations` だけで終わらせません。

理由は、それらに出ない情報がログにあるためです。実際にあった例を挙げます。

| 検証 | 表面的な症状 | ログで分かったこと |
|---|---|---|
| `23-gke-default-compute-class` | `kubectl describe pod` は `FailedScheduling` のみ | `no.scale.up.nap.pod.zonal.resources.exceeded` — NAPのCPU上限に当たっていた |
| `20-gke-cmek-node-boot-disk-rotation` | ノードが復旧していた | `compute.instances.repair.recreateInstance` — GKEの自動修復だった |

よく使うクエリを挙げます。

```bash
# 監査ログ（管理操作）
gcloud logging read 'protoPayload.serviceName="SERVICE.googleapis.com"' --limit=10 --freshness=2h

# GKEオートスケーラの判断（スケールアップ/ダウンしない理由も出る）
gcloud logging read 'logName=~"cluster-autoscaler-visibility" AND resource.labels.cluster_name="CLUSTER"' --limit=5 --freshness=2h

# Podのイベント
gcloud logging read 'resource.type="k8s_pod" AND jsonPayload.reason="REASON"' --limit=10 --freshness=2h

# コンテナのログ
gcloud logging read 'resource.type="k8s_container" AND resource.labels.pod_name=~"PREFIX"' --limit=10 --freshness=2h
```

**0件だった場合も結果として記録します。** 「ログに残らない」こと自体が運用上の判断材料になるためです。

- `19-gke-secret-manager-csi`: Secret Manager の `AccessSecretVersion`（値の読み取り）は残らない
- `20-gke-cmek-node-boot-disk-rotation`: Cloud KMS の `Encrypt` / `Decrypt`（鍵の利用）は残らない

どちらもデータアクセス監査ログが既定で無効なためで、「誰がいつ読んだか」を追跡するには明示的な有効化が要ります。

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
Basic-Examples/00-provider-check
Basic-Examples/01-project-service
Advanced-Examples/01-gce-iap-vpc
```

Terraform Resource名は、サンプル内で役割が分かる簡潔な名前を使用します。

## 6. READMEに書く内容

各サンプル / シナリオの README には最低限以下を記載します。

- 何を検証するか
- 作成されるGCPリソース
- 前提条件
- ファイル構成（実ディレクトリと一致させる。`docs/` と自動生成物を含める）
- 使用方法
- 確認方法
- **Cloud Loggingに残るもの**（0件だった場合も「残らない」と明記する）
- 削除方法
- 注意点 / 費用

`Advanced-Examples/` では特に、関係するサービス一覧とコスト・destroy 手順を明確にする。

## 7. docs/PARAMETER.md / DEPENDENCY-GRAPH.svg

各 root module に次を置く（自動生成。手動編集禁止）。

| ファイル | 生成元 |
|---|---|
| `docs/PARAMETER.md` | `terraform-docs`（設定: `.terraform-docs.yml`） |
| `DEPENDENCY-GRAPH.svg` | `terraform graph` + `dot`（設定: `.terraform-graph.conf`） |

本リポジトリでは **GitHub Actions を使わない**。ローカルで次を実行する。

```bash
./scripts/generate-terraform-docs.sh --all
./scripts/generate-terraform-graphs.sh --all
```

`.tf` 変更後は該当 module、または `--all` で再生成してからコミットする。

### リソースパラメータ対応（手書き）

コンソール / API 項目と Terraform 属性の対応表。自動生成の `docs/PARAMETER.md` とは別。

| ファイル | 役割 |
|---|---|
| `docs/PARAMETER.md` | terraform-docs。Inputs / Outputs / Resources。**手動編集禁止** |
| `docs/RESOURCE-PARAMETERS.md` | そのサンプルの明示設定と未指定（デフォルト）を、公式 Provider / GCP ドキュメントに照らして記載。**手書き** |
| `docs/INSTANCE-PARAMETERS.md` | Basic 04 のみ。GCE インスタンス項目の詳細対応（`docs/RESOURCE-PARAMETERS.md` から参照） |
| `docs/GKE-PARAMETERS.md` | Basic 07 のみ。GKE クラスタ / ノードプール項目の詳細対応（`docs/RESOURCE-PARAMETERS.md` から参照）。Advanced 03 は同ファイルを正本とし差分だけ書く |

`Basic-Examples/` および `Advanced-Examples/` の各サンプルに `docs/RESOURCE-PARAMETERS.md` を置く。値はコードのデフォルト変数を前提とし、推測の属性は書かない。

## 8. 作業ログ（`.local-logs/`）

`terraform apply` / `destroy` や動作確認コマンドの実行結果は、リポジトリ直下の `.local-logs/` に保存する。Gitにはコミットしない（`.gitignore` で除外。Project固有の値が出力に含まれるため）。

命名: `<番号>-<種別>.log`（例: `04-apply.log`, `04-verify.log`）。**Basic-Examples と Advanced-Examples で番号が重複する**ため、Advanced-Examples 側は `a<番号>-<種別>.log` とする（例: `a04-apply.log`）。

用途: 記事に載せる実行結果は、想像や既存記事からの流用ではなくここに保存した実際の出力を参照する。
