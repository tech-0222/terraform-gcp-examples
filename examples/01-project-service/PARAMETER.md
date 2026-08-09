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
| [google_project_service.apis](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| project\_id | Google Cloud Project ID where APIs are enabled. | `string` | n/a | yes |
| disable\_dependent\_services | If true, disable services that depend on the target APIs when disabling. Use carefully. | `bool` | `false` | no |
| disable\_on\_destroy | If true, terraform destroy disables the APIs. If false, APIs remain enabled after destroy. | `bool` | `false` | no |
| region | Default Google Cloud region used by the provider. | `string` | `"asia-northeast1"` | no |
| services | Google Cloud API service names to enable. See https://cloud.google.com/service-usage/docs/enabled-service | `set(string)` | <pre>[<br/>  "compute.googleapis.com",<br/>  "iam.googleapis.com",<br/>  "storage.googleapis.com"<br/>]</pre> | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| enabled\_services | API service names managed by this sample. |
| project\_id | Google Cloud Project ID where APIs were enabled. |