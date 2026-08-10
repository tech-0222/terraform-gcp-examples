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
| [google_bigquery_dataset.example](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/bigquery_dataset) | resource |
| [google_bigquery_table.example](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/bigquery_table) | resource |
| [google_project_service.bigquery](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_project_service.cloudresourcemanager](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| project\_id | Google Cloud Project ID. | `string` | n/a | yes |
| dataset\_id | BigQuery dataset ID. | `string` | `"tf_example_dataset"` | no |
| delete\_contents\_on\_destroy | Allow Terraform to delete the dataset even when it contains tables. Learning use only. | `bool` | `true` | no |
| location | BigQuery dataset location. | `string` | `"asia-northeast1"` | no |
| region | Default region for the provider. | `string` | `"asia-northeast1"` | no |
| table\_id | BigQuery table ID. | `string` | `"messages"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| dataset\_id | BigQuery dataset ID. |
| dataset\_reference | Dataset reference usable with the bq CLI. |
| project\_id | Google Cloud Project ID. |
| table\_id | BigQuery table ID. |
| table\_reference | Table reference usable with the bq CLI. |