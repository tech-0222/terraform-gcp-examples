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
| google | 7.43.0 |

## Resources

| Name | Type |
| ---- | ---- |
| [google_monitoring_alert_policy.cpu_usage](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/monitoring_alert_policy) | resource |
| [google_monitoring_notification_channel.email](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/monitoring_notification_channel) | resource |
| [google_project_service.compute](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_project_service.monitoring](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| project\_id | Google Cloud Project ID. | `string` | n/a | yes |
| alert\_policy\_name | Display name of the Cloud Monitoring alert policy. | `string` | `"tf-example-gce-cpu-high"` | no |
| alignment\_period | Alignment period used by the CPU utilization condition. | `string` | `"300s"` | no |
| cpu\_threshold | CPU utilization threshold as a ratio from 0 to 1. | `number` | `0.8` | no |
| duration | How long the threshold must be violated before an incident is opened. | `string` | `"300s"` | no |
| notification\_channel\_name | Display name of the optional email notification channel. | `string` | `"tf-example-email"` | no |
| notification\_email | Optional email address for a notification channel. Leave null to create only the alert policy. | `string` | `null` | no |
| region | Default region for the provider. | `string` | `"asia-northeast1"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| alert\_policy\_id | Cloud Monitoring alert policy resource ID. |
| alert\_policy\_name | Cloud Monitoring alert policy display name. |
| notification\_channel\_name | Notification channel resource name, or null when notification\_email is not set. |
| project\_id | Google Cloud Project ID. |