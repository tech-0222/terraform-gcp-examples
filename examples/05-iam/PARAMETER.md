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
| [google_project_iam_member.example](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_service.iam](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_service_account.example](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| project\_id | Google Cloud Project ID. | `string` | n/a | yes |
| project\_iam\_role | Project-level IAM role granted to the Service Account (least privilege example). | `string` | `"roles/storage.objectViewer"` | no |
| region | Default region for the provider. | `string` | `"asia-northeast1"` | no |
| service\_account\_display\_name | Service Account display name. | `string` | `"TF Example Service Account"` | no |
| service\_account\_id | Service Account ID (account\_id), 6-30 chars. | `string` | `"tf-example-sa"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| granted\_role | IAM role granted to the Service Account on the project. |
| service\_account\_email | Service Account email. |
| service\_account\_id | Service Account unique ID. |
| service\_account\_name | Service Account resource name. |