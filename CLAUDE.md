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

## Skill（作業の型）

| Skill | 起動 | 用途 |
| --- | --- | --- |
| `terraform-verify` | 自動／`/terraform-verify` | 変更の検証。書式・TFLint・シェル・ワークフロー・Secret・IaC助言・validate |
| `secret-scan` | commit・push前に自動 | Gitleaks による Secret 検査 |

`terraform-verify` は何度実行しても安全なので、必要と判断したときに自発的に実行してよい（手順5の `terraform init` だけはプロバイダを取得する）。対になるブログ側は `hugo-blog` の `blog-verify`。

**commit前に `terraform-verify` を通す。** 個々の検査の位置づけと、落とす／助言の区別はそこにある。

## 検証フロー

```bash
terraform init && terraform fmt -check && terraform validate && terraform plan
terraform apply
# GCP側の動作確認（4系統すべて）
# READMEと記事を書く
# 事実確認（一次ソース）→ 食い違いを実機で再確認  ← ここまで環境を残す
terraform destroy
```

**destroy は事実確認が終わってから。** 先に消すと、書いた内容に誤りが見つかっても測り直せない。GKEはコストが高いが、**測り直せない不便のほうが大きい。**

### 検証は4系統すべてで行う

**1つでも欠けたら検証として不十分。**

| 系統 | 何を見るか |
|---|---|
| 対象サービスのコマンド | 実際に動いているか（`kubectl`、`redis-cli`、`psql`、`curl`） |
| メトリクス | 取れるか、値がどう動くか（Monitoring API v3、GMP の PromQL） |
| `gcloud logging` | ログに何が残るか（**0件も結果**） |
| `gcloud <service>` | 対象サービスの状態 |

読者が運用で使うのはコンソールの**メトリクスエクスプローラとログエクスプローラ**で、`kubectl get --raw` ではない。片方だけ見て書くと実運用で使えない記事になる。**クラスタを destroy する前に4つとも取り終える。**

### 「取れない」と書く前に

- **メトリクスが空** → まず公式の収集一覧を読む。載っていなければ取れないのが仕様
- **grep が0件** → 名前と綴りを疑う。`kubelet_evictions_total` は `kubelet_evictions` だった
- **ログが0件** → 「残らない」こと自体が結果。比較対象と併せて記録する

引くべき一覧、実際にログでしか分からなかった例、よく使うクエリは [docs/VERIFICATION.md](docs/VERIFICATION.md)。

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

### Secret検査

commitまたはpushの前には必ず `secret-scan` Skillを実行する。
Gitleaksが失敗した状態ではcommit/pushしない。`--no-verify` や
`SKIP=gitleaks` を自己判断で使わない。初回は次でhookを設定する。

```bash
bash scripts/security/install-hooks.sh
```

GitleaksはAPIキー・トークン・パスワード・秘密鍵を検出する。
Project ID・メール・IPは別の確認対象なので、Gitleaksの成功だけで安全とは判断しない。

### 公開する文章の検査

**このリポジトリは公開されている。** PR・Issue の本文とコメントは、`gh pr create` などで出す**前に**次を通す。

```bash
python3 scripts/check_public_text.py --stdin < body.txt
```

CI も同じ検査を走らせるが、動くのは公開されたあとで、PR 本文の編集履歴には最初の版が残る。**最初の版から書かない。** 非公開のリポジトリ（対になるブログを含む）の Issue 番号・ファイル名・パスは書かず、「リポジトリ外の文書」など一般的な言い方にする。コミットメッセージは commit-msg フックが同じ規則で止める。

### Terraform の書式

```bash
bash scripts/lint_terraform.sh
```

**追跡下の `.tf` だけを見る。** `terraform fmt -recursive` は gitignore した各自の `terraform.tfvars` まで対象にするため、そのままでは他人の手元の整列で落ちる。導入時点で追跡下292ファイルはすべて整形済みだったので、落とす対象にしている。

**`terraform fmt` は `-check` を付けないとファイルを書き換える。** `-diff` だけでは確認にならない。

### IaC のセキュリティ設定（助言）

```bash
bash scripts/audit_iac_security.sh          # 件数と内訳
bash scripts/audit_iac_security.sh --high   # 要確認のものだけ
```

**落とさない。** 導入時点で959件（HIGH 146 / MEDIUM 397 / LOW 416）あり、大半はサンプルの趣旨そのものだった。KubernetesのデモマニフェストのKSV-*が258件、全サブネットのVPCフローログ未有効が102件など。ここをゲートにすると既存サンプルに触れなくなるだけで、質は上がらない。

**0 にすることは目的ではない。増えたときに気づけることが目的。**

ただし全部が意図ではない。次の3つは趣旨では説明できないので、スクリプトが「要確認」として分けて出す。

| ルール | 内容 |
|---|---|
| `GCP-0015` | Cloud SQL への SSL 接続が強制されていない |
| `GCP-0017` | Cloud SQL インスタンスが公開されている |
| `GCP-0061` | GKE の master authorized networks が未設定 |

**この3種は2026-09-19に確認し、現状維持と判断した。** 理由は各サンプルの README の「注意点 / 費用」に、Trivyのルール番号つきで書いてある。`GCP-0017` は `authorized_networks` が無いため実際には接続できず（`13` では `nc` で確認済み）、`GCP-0015` は平文で流れる経路が無い。`GCP-0061` だけは本当に公開エンドポイントなので、その旨を README に明記した。

**`.trivyignore` で消さない。** 消すと判断した記録が残らず、あとから増えた同種の指摘も一緒に見えなくなる。

Secret は Gitleaks の担当で、Trivy の Secret 検査は使わない。**Gitleaks は「鍵を書いていないか」、Trivy は「設定が危険でないか」**と役割を分ける。

### TFLint

`.tflint.hcl` で terraform ruleset（同梱）と google ruleset を有効にしている。**導入時点で0件。** 0件が「検査していない」ではないことは、わざと違反を置いて確認してある。

```bash
tflint --init                          # 初回。プラグインを取得する
bash scripts/lint_terraform.sh all     # fmt と tflint
```

プラグインが入っていないと、ルールが少ないまま静かに0件で通る。スクリプトはその状態を終了コード2で止める。

### `.agents` と `.claude` の同期

同じ skill を2箇所に置いている。読む側が違うため。**差分は front matter の `allowed-tools:` 1行だけで、本文は同一。**

```bash
bash scripts/check_skill_sync.sh
```

片方だけ直すと黙ってズレ、あとからどちらが正しいか見分けられない。比較するのは `.agents/` にあるものだけで、`.claude/` にしか無い skill は対象外（片側だけに在ることと、両方に在って食い違うことは別）。

### シェルとワークフローの静的検査

`.sh` と `.github/workflows/` を変更したら ShellCheck と actionlint をかける。**導入時点でどちらも0件だったので、落とす対象にしている。**

```bash
bash scripts/lint_sources.sh all
```

pre-commit hook と CI（`Lint` ワークフロー）からも走る。バイナリが無ければ Docker、どちらも無ければ終了コード2で止まる。`source` するライブラリは `-x -P SCRIPTDIR` で追跡している。

このリポジトリにPR用のCIはない（`.github/workflows/wif-demo.yml` は手動実行のデモ）。マージ前の確認は自分で行う。

## 変更しないもの

- `.terraform/`、`*.tfstate`、`.local-logs/` — Git管理外
- 他サンプルの `docs/PARAMETER.md` / `DEPENDENCY-GRAPH.svg` — 生成物
