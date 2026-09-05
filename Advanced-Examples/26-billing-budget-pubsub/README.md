# 26. 予算アラートは本当に届くのか

Cloud Billingの予算（Budget）は、コスト管理の入口としてよく紹介される。ところが実際に設定しようとすると、いくつも引っかかる。

- 予算はプロジェクトに属さない。請求アカウント配下にあり、`gcloud projects`では見えない
- APIがクォータを課す先を持たないので、プロバイダに明示が要る
- Pub/Sub通知のためにサービスエージェントへ権限を付けろ、という説明が出てくるが、**そのアカウントが存在しない**

そして最も重要な点。**予算は課金を止めない。** 上限に達しても通知が飛ぶだけで、リソースは動き続ける。

元にしたPoCは通知を請求アカウントの既定メールに任せ、Pub/Subを定義していなかった。届くかどうかを確かめていない。この例ではPub/Subに送り、**メッセージを実際に読む。**

## 構成

| リソース | 用途 |
|---|---|
| `google_billing_budget` | 予算。**請求アカウント配下** |
| `google_pubsub_topic` | 通知の宛先 |
| `google_pubsub_subscription` | 通知を読むためのpullサブスクリプション |

VMもクラスタも作らない。Pub/Subのトピックとサブスクリプションだけなので、ほぼ無料。

## provider に user_project_override が要る

`billingbudgets.googleapis.com`はuser-project-override APIで、**クォータを課す先のプロジェクトを指名する必要がある。** 予算はプロジェクトを持たないので、指名しないと課金先がない。

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

リソース名が`billingAccounts/`で始まる。**プロジェクトを削除しても予算は残る。** 逆に、プロジェクト単位の権限では予算を触れない。

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

同じく`billing-budgets-pubsub@` と `cloud-billing-budgets@` も存在しない。[公式ドキュメント](https://cloud.google.com/billing/docs/how-to/budgets-programmatic-notifications)にも具体的なアドレスの記載はなく、「Pub/Sub Publisherロールを付与する権限が必要」とだけある。

そこで**バインディングを一切付けずに**作成した。次項のとおり通知は届いた。Cloud Billing側が公開権限を自分で用意している。

### 4. 通知は届く。作成から約7分だった

```console
02:30:32  予算作成
02:31:13  受信: 0件
02:32:34  受信: 0件
...
02:37:39  受信: 1件
```

閾値を超えたその瞬間ではなく、**予算が評価されたタイミング**で publish される。

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

`data`は実支出と上限の両方を持つ。**超過分を計算するのに追加のAPI呼び出しは要らない。**

### 6. 上限を超えても課金は止まらない

上限1円に対して実支出110.03円。`alertThresholdExceeded: 1.0`が立っている。

```console
$ gcloud pubsub topics list --format="value(name.basename())"
tf-adv-budget-notifications
```

リソースは削除されず動き続けている。

**予算は通知の仕組みであって、上限ではない。** 止めたいなら、この通知を受けてリソースを停止する処理を自分で書く。Cloud FunctionsやCloud Runへpush配信し、そこで`compute instances stop`や請求の切り離しを行うのが定石。

### 7. 予算の操作は監査ログに残らない

```console
$ gcloud logging read 'protoPayload.serviceName="billingbudgets.googleapis.com"' --limit=5 --freshness=1h
（0件）
```

Pub/Sub側は残る。

```console
$ gcloud logging read 'protoPayload.serviceName="pubsub.googleapis.com"' --limit=5 --freshness=1h
（5件）
```

**誰がいつ予算を作ったか・変えたかは、このプロジェクトのログからは追えない。** コストのガードレールを外した記録が残らないという意味なので、変更管理はTerraformのコードレビューに寄せる。

## Cloud Loggingに残るもの

| ログ | クエリ | 件数 |
|---|---|---|
| 予算の作成・更新 | `protoPayload.serviceName="billingbudgets.googleapis.com"` | **0件** |
| Pub/Sub | `protoPayload.serviceName="pubsub.googleapis.com"` | 5件 |

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
- `provider`に`user_project_override`と`billing_project`が要る。予算にはクォータを課す先がない
- `budget_filter.projects`はproject **番号**を要求する
- **サービスエージェントへのIAM付与は不要だった。** 説明に出てくる3つのアドレスはいずれも存在しない
- **通知は届く。** 今回は作成から約7分。閾値超過の瞬間ではなく、予算が評価されたときに publish される
- 通知には実支出と上限の両方が入る。超過分の計算にAPI呼び出しは要らない
- **予算は課金を止めない。** 上限1円に対し110.03円でもリソースは動き続ける。止めるなら通知を受けて自分で止める
- **予算の操作は監査ログに残らない。** 変更管理はコードレビューに寄せる

## 参考資料

- [Google Cloud: Set budgets and budget alerts](https://cloud.google.com/billing/docs/how-to/budgets)
- [Google Cloud: Manage programmatic budget alert notifications](https://cloud.google.com/billing/docs/how-to/budgets-programmatic-notifications)
- [Google Cloud: Examples of programmatic budget notifications](https://cloud.google.com/billing/docs/how-to/budget-notification-format)
- [Terraform Registry: google_billing_budget](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/billing_budget)
- [Terraform Registry: user_project_override](https://registry.terraform.io/providers/hashicorp/google/latest/docs/guides/provider_reference#user_project_override)
