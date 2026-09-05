# 26 - リソースパラメータ対応

このファイルは**Cloud Billingの予算とPub/Sub通知**について対応づけます。自動生成の`docs/PARAMETER.md`とは別物です。

一次情報:

- [Google Cloud: Set budgets and budget alerts](https://cloud.google.com/billing/docs/how-to/budgets)
- [Google Cloud: Budget notification format](https://cloud.google.com/billing/docs/how-to/budget-notification-format)
- [google_billing_budget](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/billing_budget)

## 確認コマンド

```bash
# 予算はプロジェクトからは見えない。請求アカウント単位で一覧する
gcloud billing budgets list --billing-account=BILLING_ACCOUNT_ID

# 通知を読む
gcloud pubsub subscriptions pull tf-adv-budget-notifications-sub --auto-ack --limit=3 --format=json
```

## provider（予算特有の設定）

| 項目 | 本サンプル | 区分 | 備考 |
|---|---|---|---|
| `user_project_override` | `true` | 明示 | **これがないと403**。予算はプロジェクトを持たないため、クォータを課す先がない |
| `billing_project` | `var.project_id` | 明示 | 同上。`gcloud auth application-default set-quota-project` だけでは解決しない |

## google_billing_budget

| 項目 | 本サンプル | 区分 | 備考 |
|---|---|---|---|
| `billing_account` | 請求アカウントID | 明示 | **予算はここに属する。** プロジェクトを消しても残る |
| `budget_filter.projects` | `projects/<番号>` | 明示 | **project IDではなく番号。** `data.google_project` の `.number` を使う |
| `budget_filter.calendar_period` | `MONTH` | 明示 | 集計の区切り |
| `budget_filter.credit_types_treatment` | `INCLUDE_ALL_CREDITS` | 明示 | クレジットを差し引く。無料枠があると見かけの支出が下がる |
| `budget_filter.labels` | `{}`（既定） | 明示 | マップ属性。**APIが受けるキーは1つ**。空ならプロジェクト全体 |
| `amount.specified_amount` | `1 JPY` | 明示 | **上限ではなく通知の閾値** |
| `threshold_rules` | 3件 | 明示 | `CURRENT_SPEND` は実支出、`FORECASTED_SPEND` は期間終了時の予測 |
| `all_updates_rule.pubsub_topic` | トピックID | 明示 | ここを設定すると通知がPub/Subへ行く |
| `all_updates_rule.schema_version` | `1.0` | 明示 | APIが受け付ける唯一の値 |

## Pub/Sub

| 項目 | 本サンプル | 備考 |
|---|---|---|
| トピック | 1つ | `attributes.budgetId` があるので複数予算を集約できる |
| サブスクリプション | pull | 手元から読むため。本番はpushでFunctionsなどへ |
| `message_retention_duration` | `600s` | 定期通知が来るまで残る長さ |
| **publisher の IAM** | **付与しない** | 下記参照 |

### サービスエージェントへのIAM付与は不要

Pub/Sub通知の手順として、請求のサービスエージェントに`roles/pubsub.publisher`を付ける説明をよく見ます。次の3つはいずれも**存在しません**。

```
billing-budgets@system.gserviceaccount.com
billing-budgets-pubsub@system.gserviceaccount.com
cloud-billing-budgets@system.gserviceaccount.com
```

```
ERROR: INVALID_ARGUMENT: Service account ... does not exist.
```

バインディングを付けずに作成したところ、通知は届きました。公式ドキュメントにも具体的なアドレスの記載はありません。

## 実測で確認した挙動

| 項目 | 結果 | 備考 |
|---|---|---|
| 予算の所属 | `billingAccounts/.../budgets/...` | プロジェクトからは見えない |
| `budget_filter.projects` | project番号を要求 | IDを渡すと通らない |
| IAM付与 | **不要** | 3つの候補SAはいずれも存在しない |
| **通知の到達** | **届く。作成から約7分** | 閾値超過の瞬間ではなく、予算の評価時 |
| 通知の`attributes` | `billingAccountId` / `budgetId` / `schemaVersion` | 複数予算の振り分けに使える |
| 通知の`data` | 実支出・上限・超過フラグ・通貨 | 超過分の計算に追加API呼び出しが要らない |
| **上限超過時の挙動** | **課金は止まらない** | 上限1円に対し110.03円。リソースは動作継続 |
| destroy | 予算も消える | ただし請求アカウント側で確認する |

### 通知メッセージの実物

```json
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

## Cloud Loggingに残るもの

| ログ | クエリ | 件数 |
|---|---|---|
| 予算の作成・更新 | `protoPayload.serviceName="billingbudgets.googleapis.com"` | **0件** |
| Pub/Sub | `protoPayload.serviceName="pubsub.googleapis.com"` | 5件 |

**誰がいつ予算を作ったか・変えたかは追えません。** コストのガードレールを外した記録が残らないため、変更管理はTerraformのコードレビューに寄せます。

未指定（デフォルト）の項目はコンソール/APIのデフォルト値に従う。推測での記載はしない。
