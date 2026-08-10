# Parameters（自動生成）

このファイルは [terraform-docs](https://github.com/terraform-docs/terraform-docs) により自動生成されます。手動で編集しないでください。

## Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.11.0, < 2.0.0 |
| google | ~> 7.0 |

## Providers

| Name | Version |
| ---- | ------- |
| google | 7.43.0 |

## Resources

| Name | Type |
| ---- | ---- |
| [google_project_service.secretmanager](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_secret_manager_secret.example](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret) | resource |
| [google_secret_manager_secret_version.example](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret_version) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| project\_id | Google Cloud Project ID. | `string` | n/a | yes |
| secret\_data | Secret value. This is passed to the provider via a write-only argument and is not stored in Terraform plan/state. | `string` | n/a | yes |
| region | Default region for the provider. | `string` | `"asia-northeast1"` | no |
| secret\_data\_version | Version trigger for the write-only secret value. Increment when secret\_data changes. | `number` | `1` | no |
| secret\_id | Secret Manager secret ID. | `string` | `"tf-example-secret"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| secret\_id | Secret Manager secret ID. |
| secret\_name | Full resource name of the secret. |
| secret\_version | Created Secret Manager version number. |