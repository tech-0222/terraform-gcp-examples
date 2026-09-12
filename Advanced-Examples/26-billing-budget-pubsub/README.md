# 26. 予算アラートは本当に届くのか

Cloud Billingの予算（Budget）は、コスト管理の入口としてよく紹介される。ところが実際に設定しようとすると、いくつも引っかかる。

- 予算はプロジェクトに属さない。請求アカウント配下にあり、`gcloud projects`では見えない
- User ADC では API リクエストのクォータプロジェクトをプロバイダに明示する必要がある
- Pub/Sub通知のためにサービスエージェントへ権限を付けろ、という説明が出てくるが、**よく挙がるアドレスは存在しない**

そして最も重要な点。**この検証で作る通知だけの予算（alerts-only budget）は課金を止めない。** 上限に達しても通知が飛ぶだけで、リソースは動き続ける。

2026年7月27日に [Spend Cap Budget](https://cloud.google.com/billing/docs/how-to/budgets-spend-caps) が Preview で出ており、対象サービス（Gemini API / Gemini Enterprise Agent Platform / Cloud Run / Cloud Run functions）なら自動停止できる。**ただしこのサンプルの方法では作れない。**

```console
$ gcloud billing budgets create --help | grep -icE "spend.?cap|enforce"
0        # alpha / beta も同じ。--billing-account / --budget-amount /
         # --filter-projects / --notifications-rule-pubsub-topic などはあるが、
         # 上限を強制する引数は無い
```

Budget API v1 のリソース項目は `name` / `displayName` / `budgetFilter` / `amount` / `thresholdRules` / `notificationsRule` / `etag` / `ownershipScope` で、`spendCap` にあたるものが無い。`google_billing_budget` の引数も同様。公式の手順も Console だけを案内している。**確かめた範囲では手段が無い。** 公開 API に出れば provider が追える性質のもので、将来もできないという話ではない。

制約も強い。単一プロジェクト × 単一サービス、期間は Monthly 固定、Folder / Organization / ラベル / 複数プロジェクトは対象外。止まるのは新規の利用だけ。処理中のリクエストは完了まで進んで課金され、Compute や Storage のような永続リソースの固定費は止まらない。コスト反映の遅れによる超過分も通常どおり課金される。解除は Console で「Lift spend cap」を選び、復帰に最大1時間かかる。

元にしたPoCは通知を請求アカウントの既定メールに任せ、Pub/Subを定義していなかった。届くかどうかを確かめていない。この例ではPub/Subに送り、**メッセージを実際に読む。**

## 構成

| リソース | 用途 |
|---|---|
| `google_billing_budget` | 予算。**請求アカウント配下** |
| `google_pubsub_topic` | 通知の宛先 |
| `google_pubsub_subscription` | 通知を読むためのpullサブスクリプション |

VMもクラスタも作らない。Pub/Subのトピックとサブスクリプションだけなので、ほぼ無料。

## User ADC では provider に user_project_override が要る

User ADC で Budget API を呼ぶなら、**API のクォータプロジェクトを明示する必要がある。** [Terraform の公式資料](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/billing_budget)も、User ADC では `user_project_override = true` と `billing_project` の両方を求めている。

`billing_project` はクォータの請求先であって、予算が属する請求アカウントや、予算が集計する費用の対象とは別。

```hcl
provider "google" {
  project = var.project_id
  region  = var.region

  user_project_override = true
  billing_project       = var.project_id
}
```

これがないと、こうなる。

```text
Error creating Budget: googleapi: Error 403: Your application is authenticating
by using local Application Default Credentials. The billingbudgets.googleapis.com
API requires a quota project, which is not set by default.
```

`gcloud auth application-default set-quota-project`だけでは解決しない。

## budget_filter.projects は「番号」

project IDではなく、`projects/<番号>`の形式を要求する。

```hcl
data "google_project" "scope" {
  project_id = var.project_id
}

resource "google_billing_budget" "main" {
  budget_filter {
    projects = ["projects/${data.google_project.scope.number}"]
  }
}
```

## 前提

- Terraform 1.10以上、`hashicorp/google` 7.x
- 請求アカウントに対する`roles/billing.admin`または`roles/billing.costsManager`
- 通知先トピックの`pubsub.topics.setIamPolicy`（Budget API が Publisher ロールを付けるのに要る）
- Pub/Sub のトピックとサブスクリプションを作成・削除・受信する権限
- User ADC を使う場合、`billing_project` に指定するプロジェクトの`serviceusage.services.use`
- 有効化するAPI: `billingbudgets` / `cloudbilling` / `pubsub`

`billingbudgets.googleapis.com`が無効だと、`gcloud billing budgets list`すら通らない。

```bash
gcloud services enable billingbudgets.googleapis.com
gcloud billing accounts list          # billing_account_id を調べる
```

## 実行

```bash
cp terraform.tfvars.example terraform.tfvars
# project_id と billing_account_id を自分の値に書き換える
terraform init
terraform apply
```

## 検証環境

```
Terraform v1.14.5
provider registry.terraform.io/hashicorp/google v7.46.0
```

## 検証結果

### 1. 予算はプロジェクトの外にある

```console
$ gcloud billing budgets list --billing-account=BILLING_ACCOUNT_ID \
    --filter="displayName:tf-adv" --format="value(name,displayName)"
billingAccounts/BILLING_ACCOUNT_ID/budgets/3198661d-c1c0-4446-862b-a89a93f6754f	tf-adv-budget-pubsub
```

リソース名が`billingAccounts/`で始まる。**プロジェクトを削除しても予算は残る。** なお、[単一プロジェクトを対象にする予算](https://cloud.google.com/billing/docs/how-to/budget-api-access-control)なら、プロジェクト側の権限（`resourcemanager.projects.get` / `billing.resourcebudgets.read` / `billing.resourcebudgets.write`）でも作成できる。

### 2. 設定はそのまま格納される

```console
$ gcloud billing budgets describe BUDGET --billing-account=BILLING_ACCOUNT_ID \
    --format="yaml(amount,budgetFilter,thresholdRules,notificationsRule)"
amount:
  specifiedAmount:
    currencyCode: JPY
    units: '1'
budgetFilter:
  calendarPeriod: MONTH
  creditTypesTreatment: INCLUDE_ALL_CREDITS
  projects:
  - projects/YOUR_PROJECT_NUMBER
notificationsRule:
  pubsubTopic: projects/YOUR_PROJECT_ID/topics/tf-adv-budget-notifications
  schemaVersion: '1.0'
thresholdRules:
- spendBasis: CURRENT_SPEND
  thresholdPercent: 0.5
- spendBasis: CURRENT_SPEND
  thresholdPercent: 1.0
- spendBasis: FORECASTED_SPEND
  thresholdPercent: 1.0
```

`CURRENT_SPEND`は使った金額、`FORECASTED_SPEND`は期間終了時点の予測。**別の問いに答えるので、両方置くことが多い。**

### 3. サービスエージェントへのIAM付与は不要だった

Pub/Sub通知の手順として、請求のサービスエージェントに`roles/pubsub.publisher`を付けるという説明をよく見る。試したところ、候補として挙がる3つはいずれも存在しない。

```console
$ gcloud pubsub topics add-iam-policy-binding tf-adv-budget-notifications \
    --member="serviceAccount:billing-budgets@system.gserviceaccount.com" \
    --role=roles/pubsub.publisher
ERROR: INVALID_ARGUMENT: Service account billing-budgets@system.gserviceaccount.com does not exist.
```

同じく`billing-budgets-pubsub@` と `cloud-billing-budgets@` も存在しない。

正しいプリンシパルは `billing-budget-alert@system.gserviceaccount.com`。[ドメイン制限共有の除外設定](https://cloud.google.com/organization-policy/restrict-domains)のページに、Pub/Sub で予算アラートを受け取る際のプリンシパルとして載っている。

**手で付けなくても通知は届いた。** 作成後にトピックの IAM Policy を見ると、Budget API が自分で付けている。

```console
$ gcloud pubsub topics get-iam-policy tf-adv-budget-notifications --format=json
{
  "bindings": [
    {
      "members": [
        "serviceAccount:billing-budget-alert@system.gserviceaccount.com"
      ],
      "role": "roles/pubsub.publisher"
    }
  ]
}
```

`budget.tf` には IAM バインディングを1つも書いていない。設定する側に `pubsub.topics.setIamPolicy` があれば足りる。

そこで**バインディングを一切付けずに**作成した。次項のとおり通知は届いた。Cloud Billing側が公開権限を自分で用意している。

### 4. 通知は届く。作成から約7分だった

```console
02:30:32  予算作成
02:31:13  受信: 0件
02:32:34  受信: 0件
...
02:37:39  受信: 1件
```

[Pub/Sub 通知が送られるのは](https://cloud.google.com/billing/docs/how-to/budgets-programmatic-notifications)閾値を超えた瞬間ではなく、**現在の予算の状態が1日に複数回**送られる。公式には初回まで数時間かかることがあるとされており、今回7分で届いたのは早いほう。

配信は at-least-once。同じ内容が複数回届くことも、順序が入れ替わることもある。**通知を受けて処理を書くなら、何度実行しても同じ結果になるようにする。**

### 5. 通知の中身

```console
$ gcloud pubsub subscriptions pull tf-adv-budget-notifications-sub --auto-ack --limit=3 --format=json
```

```text
--- attributes ---
  billingAccountId: BILLING_ACCOUNT_ID
  budgetId: 3198661d-c1c0-4446-862b-a89a93f6754f
  schemaVersion: 1.0
--- data ---
{
  "budgetDisplayName": "tf-adv-budget-pubsub",
  "alertThresholdExceeded": 1.0,
  "costAmount": 110.03,
  "costIntervalStart": "2026-09-01T07:00:00Z",
  "budgetAmount": 1.0,
  "budgetAmountType": "SPECIFIED_AMOUNT",
  "currencyCode": "JPY",
  "forecastThresholdExceeded": 1.0
}
```

`attributes`に`budgetId`があるので、複数の予算を1つのトピックに集約しても振り分けられる。

`data`は[累積コスト](https://cloud.google.com/billing/docs/how-to/budgets-programmatic-notifications)（`costAmount`）と予算額（`budgetAmount`）の両方を持つ。**超過分を計算するのに追加のAPI呼び出しは要らない。** `costAmount` は確定した請求額ではなく、使用量からコストへの反映には遅れがある。

### 6. 上限を超えてもリソースは止まらなかった

予算額1円に対して `costAmount` は110.03円。`alertThresholdExceeded: 1.0`が立っている。

```console
$ gcloud pubsub topics list --format="value(name.basename())"
tf-adv-budget-notifications
```

トピックは一覧に残っている。ただし一覧に出るかどうかを見ただけで、送受信が続くかは確かめていない。言えるのは「超過しても、このトピックが自動で消えることはなかった」ところまで。

ただしこの検証で作るのは Pub/Sub のトピックとサブスクリプションだけ。**言えるのは「超過してもリソースが自動で消されない」ところまでで、その後も課金が増え続けたことは測っていない。** 通知だけの予算が spending cap でないことは[公式の仕様](https://cloud.google.com/billing/docs/how-to/budgets)であり、実測はそれと矛盾しない。

止めたいなら、この通知を受けてリソースを停止する処理を自分で書く。Cloud FunctionsやCloud Runへpush配信し、そこで`compute instances stop`を行う形。請求の無効化も[公式に案内がある](https://cloud.google.com/billing/docs/how-to/budgets)が、サービスが止まりデータに影響が出ることがある。

### 7. 予算の操作は監査ログで追えなかった

```console
$ gcloud logging read 'protoPayload.serviceName="billingbudgets.googleapis.com"' --limit=5 --freshness=8h
（0件）
```

同じ窓で他のサービスは出ている。ログ機能そのものは動いている。

```console
$ for S in billingbudgets pubsub serviceusage; do
    printf "%-16s %s件\n" "$S" "$(gcloud logging read "protoPayload.serviceName=\"$S.googleapis.com\"" \
      --limit=10 --freshness=8h --format="value(timestamp)" | wc -l)"
  done
billingbudgets   0件
pubsub           10件
serviceusage     8件
```

**「残らない」とは言い切れない。** 予算は請求アカウント配下のリソースなので、監査ログも
請求アカウントのスコープに出ている可能性がある。今回はそのスコープで検索して0件だった。読めなかったのではない。

```console
$ gcloud billing accounts get-iam-policy BILLING_ACCOUNT_ID --format="value(bindings.role)"
roles/billing.admin
roles/billing.costsManager
roles/billing.user
```

請求アカウントスコープの `gcloud logging read --billing-account=...` は何も返さなかった。
**ただしこれを権限不足とは判断できない。**

```console
$ gcloud iam roles describe roles/billing.admin --format='value(includedPermissions)' \
    | tr ';' '\n' | grep logging
logging.logEntries.list
logging.logServiceIndexes.list
logging.logServices.list
logging.logs.list
logging.privateLogEntries.list
```

`roles/billing.admin` にログ閲覧の権限が含まれている。また上のコマンドが出すのは
ロール名だけで、実行者への付与状況までは分からない。**0件の原因は特定できていない。**

なお、データアクセス監査ログはこのプロジェクトで未設定（`auditConfigs`なし）だが、
**そもそも Budget API は監査ログを出さない可能性が高い。** [監査ログに対応するサービスの一覧](https://cloud.google.com/logging/docs/audit/services)に `cloudbilling.googleapis.com` はあるが、`billingbudgets.googleapis.com` は無い。[Cloud Billing の監査ログ](https://cloud.google.com/billing/docs/audit-logging)にも予算の操作は対象メソッドとして挙がっていない。
有効・無効の設定が理由ではない。

分かっているのは次の1点だけ。

- **プロジェクトの監査ログを見ても、予算を誰がいつ作ったかは分からない**

請求アカウントのログを追う場合は、`--billing-account`スコープで読む。

## Cloud Loggingに残るもの

| ログ | クエリ | 件数 | 備考 |
|---|---|---|---|
| 予算の作成・更新 | `protoPayload.serviceName="billingbudgets.googleapis.com"` | **0件** | プロジェクトスコープ。請求アカウント側は未確認 |
| Pub/Sub | `protoPayload.serviceName="pubsub.googleapis.com"` | 10件 | |
| API有効化 | `protoPayload.serviceName="serviceusage.googleapis.com"` | 8件 | |

上2つが出ているので、ログ機能自体は動いている。予算だけが出ない。

## 後片付け

```console
$ terraform destroy
```

```console
$ gcloud billing budgets list --billing-account=BILLING_ACCOUNT_ID --filter="displayName:tf-adv"
（0件）
```

**予算は請求アカウント配下にあるので、`terraform state list`が0件でも安心しない。** 上のコマンドで消えたことを確かめる。

## まとめ

- **予算はプロジェクトに属さない。** 請求アカウント配下にあり、プロジェクトを消しても残る
- **User ADC では**`provider`に`user_project_override`と`billing_project`が要る。API リクエストのクォータプロジェクトを指定する
- `budget_filter.projects`はproject **番号**を要求する
- **Publisher ロールの手動付与は不要だった。** よく挙がる3つのアドレスは存在せず、実際は `billing-budget-alert@system.gserviceaccount.com` が使われる
- **通知は届く。** 今回は作成から約7分。ただし公式には初回まで数時間かかることがある。閾値超過の瞬間ではなく現在の状態が1日に複数回送られ、配信は at-least-once
- 通知には累積コストと予算額の両方が入る。超過分の計算にAPI呼び出しは要らない
- **通知だけの予算は課金を止めない。** 上限1円に対し110.03円でもトピックは残る。測ったのは「消されない」ところまで
- **Spend Cap Budget は、確かめた範囲では Terraform から作れなかった。** gcloud 562.0.0・Budget API v1・provider 7.46.0 のどれにも該当する引数が無い。公開 API に出れば provider が追える
- **予算の操作は監査ログで追えなかった。** `billingbudgets.googleapis.com` は監査ログ対応サービスの一覧に無く、少なくとも2026年9月の時点では追跡できると確認できない

## 参考資料

- [Google Cloud: Set budgets and budget alerts](https://cloud.google.com/billing/docs/how-to/budgets)
- [Google Cloud: Manage programmatic budget alert notifications](https://cloud.google.com/billing/docs/how-to/budgets-programmatic-notifications)
- [Google Cloud: Examples of programmatic budget notifications](https://cloud.google.com/billing/docs/how-to/budget-notification-format)
- [Terraform Registry: google_billing_budget](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/billing_budget)
- [Terraform Registry: user_project_override](https://registry.terraform.io/providers/hashicorp/google/latest/docs/guides/provider_reference#user_project_override)
