# Parameters（自動生成）

このファイルは [terraform-docs](https://github.com/terraform-docs/terraform-docs) により自動生成されます。手動で編集しないでください。

## Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.10.0, < 2.0.0 |
| google | ~> 7.0 |

## Providers

| Name | Version |
| ---- | ------- |
| google | 7.46.1 |

## Resources

| Name | Type |
| ---- | ---- |
| [google_billing_budget.main](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/billing_budget) | resource |
| [google_project_service.required](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_pubsub_subscription.budget](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/pubsub_subscription) | resource |
| [google_pubsub_topic.budget](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/pubsub_topic) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| billing\_account\_id | Billing account the budget belongs to (e.g. 012345-6789AB-CDEF01). Note that the budget lives here, NOT in the project -- deleting the project does not remove it. Find it with `gcloud billing accounts list`. | `string` | n/a | yes |
| project\_id | Google Cloud Project ID. The budget scopes to this project's spend. | `string` | n/a | yes |
| budget\_amount\_units | Budget amount in whole currency units. This is a notification threshold, not a spending cap -- exceeding it stops nothing. | `number` | `1` | no |
| budget\_display\_name | Name shown in the console. Budgets are not namespaced by project, so make it identifiable. | `string` | `"tf-adv-budget-pubsub"` | no |
| budget\_labels | Restrict the budget to spend carrying this label. An empty map covers the whole project. The API accepts one key, not several. | `map(string)` | `{}` | no |
| calendar\_period | Period the spend is accumulated over. MONTH resets on the first of each month. | `string` | `"MONTH"` | no |
| credit\_types\_treatment | How credits count toward the threshold. INCLUDE\_ALL\_CREDITS subtracts them, so free-tier usage lowers the apparent spend; EXCLUDE\_ALL\_CREDITS shows list price. | `string` | `"INCLUDE_ALL_CREDITS"` | no |
| currency\_code | Currency. Must match the billing account's currency. | `string` | `"JPY"` | no |
| region | Region for the Pub/Sub resources. | `string` | `"asia-northeast1"` | no |
| threshold\_rules | When to notify. CURRENT\_SPEND fires on money already spent; FORECASTED\_SPEND fires on the projection for the period. They answer different questions. | <pre>list(object({<br/>    threshold_percent = number<br/>    spend_basis       = string<br/>  }))</pre> | <pre>[<br/>  {<br/>    "spend_basis": "CURRENT_SPEND",<br/>    "threshold_percent": 0.5<br/>  },<br/>  {<br/>    "spend_basis": "CURRENT_SPEND",<br/>    "threshold_percent": 1<br/>  },<br/>  {<br/>    "spend_basis": "FORECASTED_SPEND",<br/>    "threshold_percent": 1<br/>  }<br/>]</pre> | no |
| topic\_name | Pub/Sub topic the budget publishes to. | `string` | `"tf-adv-budget-notifications"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| budget\_name | Full resource name. Note the billingAccounts/ prefix: this is not a project resource. |
| list\_budgets\_example | Budgets are not visible through `gcloud projects`. They are listed per billing account. |
| project\_id | Google Cloud Project ID. |
| pull\_notification\_example | Read a budget notification. They arrive on a schedule, not only when a threshold is crossed, so this returns something even below the limit. |
| scoped\_project\_number | budget\_filter.projects needs the project NUMBER, not the ID. |
| subscription\_name | Pull subscription for reading the notifications. |
| topic\_name | Pub/Sub topic receiving budget notifications. |