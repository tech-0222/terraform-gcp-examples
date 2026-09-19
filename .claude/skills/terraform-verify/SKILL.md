---
name: terraform-verify
description: Terraformサンプルの変更が壊れていないことを検証する。書式、TFLint、シェル、ワークフロー、Secret、IaCセキュリティ、変更したモジュールのvalidateとplanを実行し、結果を報告する。commitやPR作成の前に使用する。
allowed-tools: Bash, Read, Grep, Glob
---

サンプルの変更が壊れていないことを検証する。

この検証は副作用がなく、何度実行しても安全。**ただし手順5だけは `terraform init` でプロバイダを取得する。**

対になるブログ側は `hugo-blog` の `blog-verify` skill。

## 前提

- `terraform` が要る。無ければ手順1と5は終了コード2で止まる
- `tflint` は初回に `tflint --init` が要る。**プラグインが無いとルールが少ないまま静かに0件で通る**ので、スクリプトがその状態を終了コード2で撥ねる
- `shellcheck` / `actionlint` / `gitleaks` はバイナリが無ければ Docker で走る。どちらも無ければ終了コード2
- **「実行できなかった」を0件と同じ値で返さない。** どの検査も、通らなかったのか通ったのかを終了コードで区別する

## 手順

### 1. 書式と言語ルール

```bash
bash scripts/lint_terraform.sh all      # fmt と tflint。個別なら fmt / tflint
```

`terraform fmt` は**追跡下のファイルだけ**を見る。`-recursive` は作業ツリー全体を走るので、gitignore した各自の `terraform.tfvars` まで対象に入るため。

TFLint は `.tflint.hcl` の terraform ruleset（同梱）と google ruleset を使う。**どちらも導入時点で0件。** これから書くものだけが落ちる。

### 2. シェルとワークフロー

```bash
bash scripts/lint_sources.sh all        # 個別なら shell / actions
```

ShellCheck と actionlint。**導入時点で両方0件。**

`actionlint` は `uses:` の参照先が実在するかまでは見ない。**ワークフローにactionを足したら、タグの実在を確かめる。**

```bash
gh api repos/<owner>/<action>/tags --jq '.[0:5][].name'
```

### 3. Secret

```bash
bash scripts/security/secret-scan.sh staged    # commit前
bash scripts/security/secret-scan.sh push      # push前
```

手順は `secret-scan` skill にある。**検出値そのものを会話やログへ転載しない。**

### 4. IaC のセキュリティ設定（助言）

```bash
bash scripts/audit_iac_security.sh             # 件数と内訳
bash scripts/audit_iac_security.sh --high      # 要確認のものだけ
```

**落とさない。** 導入時点で959件あり、大半はサンプルの趣旨そのものだった（GKEのデモ用マニフェスト258件、全サブネットのVPCフローログ未有効102件など）。最小構成で特定機能を示すために省いているものを落とすと、既存サンプルに触れなくなるだけで質は上がらない。

**0 にすることは目的ではない。増えたときに気づけることが目的。**

ただし全部が意図ではない。次の3つは趣旨で説明できないので、スクリプトが「要確認」として分けて出す。

| ルール | 内容 |
|---|---|
| `GCP-0015` | Cloud SQL への SSL 接続が強制されていない |
| `GCP-0017` | Cloud SQL インスタンスが公開されている |
| `GCP-0061` | GKE の master authorized networks が未設定 |

Secret は Gitleaks の担当で、Trivy の Secret 検査は使わない。**Gitleaks は「鍵を書いていないか」、Trivy は「設定が危険でないか」。**

### 5. 変更したモジュールの validate と plan

**変更したディレクトリだけにかける。** 45モジュールすべてに `terraform init` をかけると、プロバイダの取得だけで時間がかかる。

```bash
for d in $(git diff --name-only origin/main...HEAD -- '*.tf' | xargs -r -n1 dirname | sort -u); do
  echo "=== $d ==="
  terraform -chdir="$d" init -backend=false -input=false
  terraform -chdir="$d" validate
done
```

`-backend=false` はバックエンドの初期化を飛ばす。検証に認証は要らない。

**`plan` は実際の認証と課金対象の参照が要る。** 構成を作る前の確認として打つ場合は、`terraform.tfvars` を用意したうえで各ディレクトリで実行する。恒常差分が出ていないかは `-detailed-exitcode` で見る。

```bash
terraform -chdir="$d" plan -detailed-exitcode     # 0=差分なし 2=差分あり
```

**恒常差分を抱えたまま測ると結果が壊れる。** 記事46では、NEGエンドポイントの `instance` に `self_link` を渡していたために apply のたびに作り直され、`get-health` が1台しか返さない状態で測りかけた。

### 6. 生成物の再生成（`.tf` を変更した場合）

```bash
./scripts/generate-terraform-docs.sh --changed-from origin/main
./scripts/generate-terraform-graphs.sh --changed-from origin/main
```

`docs/PARAMETER.md` と `DEPENDENCY-GRAPH.svg` は生成物で、**手で編集しない。** `--all` は全モジュールを回すので、変更分だけでよいときは `--changed-from` を使う。

### 7. 後片付け

```bash
find . -name '.terraform' -maxdepth 3 -type d | head        # init の残骸
git status --short                                          # 生成物の差分
```

`.terraform/` は Git 管理外。消しても `terraform init` で戻る。

## 落とす検査と助言

| 区分 | 検査 | 導入時点 |
|---|---|---|
| 落とす | Gitleaks / ShellCheck / actionlint / terraform fmt / TFLint | すべて0件 |
| 助言 | Trivy config | 959件 |

**どれも終了コード2（実行できなかった）は落とす。**

落とす側はすべて pre-commit hook からも走る。初回は次で有効にする。

```bash
bash scripts/security/install-hooks.sh
```

## 報告

以下を明示する。

- 各手順の成否（書式／TFLint／シェル／ワークフロー／Secret／IaC助言／validate／生成物）
- 検出した問題の内容と、それがどのファイルに起因するか
- **実行していない検証があれば、実行していないと書く**
- Trivy の件数が前回から増えていれば、増えた分の内訳

## 制約

- 検証だけを行う。問題を見つけても、指示なく修正しない
- 検証が失敗した状態を成功として報告しない
- 実行していない確認を実行したと書かない
- **0件を「問題なし」と読まない。** 検査が動いていないだけのことがある。疑わしいときは、わざと違反を置いて落ちることを確かめる
- チェッカーを通すために検査対象を狭める、チェッカー自体を緩めるといった対処をしない
- **`terraform fmt` に `-check` を付け忘れない。** 付けないとファイルを書き換える。`-diff` だけでは確認にならない
- **この検証は `terraform destroy` の前に終える。** 消したあとでは、指摘を受けても確かめ直せない
