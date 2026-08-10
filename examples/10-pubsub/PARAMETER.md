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
| [google_project_service.pubsub](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_pubsub_subscription.example](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/pubsub_subscription) | resource |
| [google_pubsub_topic.example](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/pubsub_topic) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| project\_id | Google Cloud Project ID. | `string` | n/a | yes |
| ack\_deadline\_seconds | Initial acknowledgement deadline for pulled messages. | `number` | `20` | no |
| region | Default region for the provider. | `string` | `"asia-northeast1"` | no |
| subscription\_name | Pub/Sub pull subscription name. | `string` | `"tf-example-subscription"` | no |
| topic\_name | Pub/Sub topic name. | `string` | `"tf-example-topic"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| publish\_example | Example command to publish a test message. |
| pull\_example | Example command to pull one message. |
| subscription\_name | Pub/Sub subscription name. |
| topic\_name | Pub/Sub topic name. |