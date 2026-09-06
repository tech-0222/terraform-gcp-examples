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

**ただし実測は仕様の根拠にならない。** 「取れなかった」と「取れない」は別の主張で、後者には一次ソースが要る。

| 根拠 | 保証するもの |
|---|---|
| コマンドの出力 | その1回、その環境で何が起きたか |
| 一次ソース | 製品が何を約束しているか |

**0件を「存在しない」と書く前に、名前と綴りを疑う。** grep のパターンが違っただけ、というのが実際にあった。

## 検証フロー

```bash
terraform init
terraform fmt -check
terraform validate
terraform plan
terraform apply
# GCP側の動作確認（下記「検証は4系統すべてで行う」）
# READMEと記事を書く
# 事実確認（一次ソース）
# 食い違いを実機で再確認 ← ここまで環境を残す
terraform destroy
```

**destroy は事実確認が終わってから。** 先に消すと、書いた内容に誤りが見つかっても測り直せない。

実際にそうなった。`28-gke-pod-eviction` で「`kubelet_evictions_total` は存在しない」と書いたが、正しい名前は `kubelet_evictions` だった。`_total` 付きで `grep` して0件になり、名前ではなく存在を疑った。**気づいたのは destroy のあとで、GKE 上に実在したかは今も確かめられない。**

**GKEは最もコストが高い。** ただし、測り直せない不便のほうが大きい。事実確認まで一気に終わらせてから消す。

### 検証は4系統すべてで行う

**GCPリソースを作る検証では、次の4つをすべて実行する。** 1つでも欠けたら検証として不十分。

| 系統 | 何を見るか | 例 |
|---|---|---|
| 対象サービスのコマンド | 実際に動いているか | `kubectl`、`redis-cli`、`psql`、`curl`、`systemctl` |
| メトリクス | 取れるか、値がどう動くか | Monitoring API v3 の `timeSeries`、GMP の PromQL |
| `gcloud logging` | ログに何が残るか（**0件も結果**） | `gcloud logging read` |
| `gcloud <service>` | 対象サービスの状態 | `gcloud container`、`gcloud certificate-manager` |

読者が運用で使うのはコンソールの**メトリクスエクスプローラとログエクスプローラ**であって、`kubectl get --raw` ではない。片方だけ見て書くと、実運用で使えない記事になる。

`gcloud monitoring` に時系列のサブコマンドは無い（あるのは dashboards と policies）。時系列は Monitoring API v3 を直接呼び出す。

GKE では GMP（`monitoring_config.managed_prometheus`）を有効にし、PromQL で引けるところまで確認する。**クラスタを destroy する前に4つとも取り終える。**

### メトリクスが空だったら、まず一覧を読む

**「取れない」を実測だけで結論づけない。** マネージド収集は集めるメトリクスが公式に列挙されており、載っていなければ取れないのが仕様になる。

| 対象 | 一覧 |
|---|---|
| GKE の kube state metrics | [Collect and view kube state metrics](https://cloud.google.com/kubernetes-engine/docs/how-to/kube-state-metrics) |
| GKE の cAdvisor / kubelet | [cAdvisor and kubelet metrics](https://cloud.google.com/kubernetes-engine/docs/how-to/cadvisor-kubelet-metrics) |

`28-gke-pod-eviction` で、`kube_pod_status_reason` が0件だった理由を「実測から言えるのは組み込みの収集が狭いということ」と書いた。**実際は上の一覧に載っていないだけで、公式に文書化されていた。** 調べれば分かることを未解明として書かない。

自前デプロイ用のエクスポーター設定（`stackdriver/docs/managed-prometheus/exporters/`）と、GKE 組み込みの一覧は**別物**。取り違えると説明が合わなくなる。

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
