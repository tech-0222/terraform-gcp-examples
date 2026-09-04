# CLAUDE.md

Terraform × Google Cloud の検証コード置き場。このファイルはリポジトリの恒常ルールを記述する。詳細は `docs/CONVENTIONS.md` にある。

## リポジトリ概要

| 置き場 | 役割 |
|---|---|
| `Basic-Examples/` | 基本。1トピック = 1 Root Module |
| `Advanced-Examples/` | 応用。複数サービス連携や実践的な試験コード |
| `modules/` | 共通モジュール。重複が目立ってから追加する（先に作らない） |

対になるブログは `../hugo-blog`。各サンプルは記事と1対1で対応する。

## 絶対に守ること

### moduleを使わない

**`module` ブロックを書かない。** `google_*` リソースを直接書く。各サンプルは、そのディレクトリだけで `terraform apply` できる独立したRoot Moduleにする。

`versions.tf` の `source = "hashicorp/google"` はproviderの指定であってmoduleではない。

### Secretをコミットしない

- `terraform.tfvars`、`*.tfstate`、`.local-logs/`、シークレットの値を含むファイルはコミットしない
- `google_secret_manager_secret_version` の `secret_data` を使わない。**平文が `terraform.tfstate` に残る。** 器だけをTerraformで作り、値は `gcloud secrets versions add --data-file=-` で投入する
- README・コードに Project ID / Project Number / gcloudアカウント / 手元のグローバルIP を書かない。プレースホルダーに置き換える
- GCPが払い出したリソースのIP・名前（Node名、Cloud SQLのIPなど）は対象外。destroy後に失効する値であり、書き手を特定しない

### 検証したことだけ書く

READMEに載せる実行結果は、実際に `terraform apply` 等を実行した出力を使う。想像や他サンプルからの流用はしない。

## 検証フロー

```bash
terraform init
terraform fmt -check
terraform validate
terraform plan
terraform apply
# GCP側の動作確認
# Cloud Logging の確認（下記）
terraform destroy
```

**GKEは最もコストが高い。検証後は速やかに `terraform destroy` する。**

### Cloud Logging を必ず確認する

**GCPリソースを作成する検証では、毎回 `gcloud logging read` でログを確認する。** `kubectl describe` や `gcloud ... operations` だけで終わらせない。

それらに出ない情報がログにある。実際にあった例を挙げる。

| サンプル | 表面的な症状 | ログで分かったこと |
|---|---|---|
| `23-gke-default-compute-class` | `kubectl describe pod` は `FailedScheduling` のみ | `no.scale.up.nap.pod.zonal.resources.exceeded` — NAPのCPU上限に当たっていた |
| `20-gke-cmek-node-boot-disk-rotation` | ノードが復旧していた | `compute.instances.repair.recreateInstance` — GKEの自動修復だった |

```bash
# 監査ログ（管理操作）
gcloud logging read 'protoPayload.serviceName="SERVICE.googleapis.com"' --limit=10 --freshness=2h

# GKEオートスケーラの判断（スケールしない理由も出る）
gcloud logging read 'logName=~"cluster-autoscaler-visibility" AND resource.labels.cluster_name="CLUSTER"' --limit=5 --freshness=2h

# Podのイベント
gcloud logging read 'resource.type="k8s_pod" AND jsonPayload.reason="REASON"' --limit=10 --freshness=2h

# コンテナのログ
gcloud logging read 'resource.type="k8s_container" AND resource.labels.pod_name=~"PREFIX"' --limit=10 --freshness=2h
```

**0件だった場合も結果として記録する。** 「ログに残らない」こと自体が運用上の判断材料になる。

- `19-gke-secret-manager-csi`: Secret Manager の `AccessSecretVersion`（値の読み取り）は残らない
- `20-gke-cmek-node-boot-disk-rotation`: Cloud KMS の `Encrypt` / `Decrypt`（鍵の利用）は残らない

どちらもデータアクセス監査ログが既定で無効なためで、「誰がいつ読んだか」を追跡するには明示的な有効化が要る。

### 作業ログ

実行結果は `.local-logs/` に残す。Gitにはコミットしない。命名は `docs/CONVENTIONS.md` の「作業ログ」に従う。

## ドキュメント生成

`.tf` を変更したら再生成してからコミットする。**GitHub Actionsは使わない。ローカルで実行する。**

```bash
./scripts/generate-terraform-docs.sh Advanced-Examples/<name>
./scripts/generate-terraform-graphs.sh Advanced-Examples/<name>
```

| ファイル | 生成元 | 編集 |
|---|---|---|
| `docs/PARAMETER.md` | `terraform-docs` | **手動編集禁止** |
| `DEPENDENCY-GRAPH.svg` | `terraform graph` + `dot` | **手動編集禁止** |
| `docs/RESOURCE-PARAMETERS.md` | 手書き | コンソール/API項目とTerraform属性の対応表 |

## READMEに書く内容

- 何を検証するか
- 作成されるGCPリソース
- 前提条件
- 使用方法
- 確認方法
- **Cloud Loggingに残るもの**（0件だった場合も「残らない」と明記する）
- 削除方法
- 注意点 / 費用

`Advanced-Examples/` では特に、関係するサービス一覧とコスト・destroy手順を明確にする。

## 命名

- ディレクトリ: `<2桁番号>-<英語ケバブケース>`
- GCPリソース名: `tf-adv-*`（Advanced）/ `tf-example-*`（Basic）

既存の命名に合わせる。混在させない。

## Git運用

- `main` へ直接コミットしない。必ずブランチを切る
- ブランチ名: `feature/<topic>`、修正は `fix/<topic>`、ドキュメントは `docs/<topic>`
- **`git add -A` や `git add .` を使わない。** ファイルを個別に指定する
- コミットメッセージにセッションURL（`Claude-Session:` トレーラー等）を含めない。パブリックリポジトリに残る

このリポジトリにPR用のCIはない（`.github/workflows/wif-demo.yml` は手動実行のデモ）。マージ前の確認は自分で行う。

## 変更しないもの

- `.terraform/`、`*.tfstate`、`.local-logs/` — Git管理外
- 他サンプルの `docs/PARAMETER.md` / `DEPENDENCY-GRAPH.svg` — 生成物
