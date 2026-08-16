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
| [google_project_service.sqladmin](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_sql_database.example](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/sql_database) | resource |
| [google_sql_database_instance.example](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/sql_database_instance) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| project\_id | Google Cloud Project ID. | `string` | n/a | yes |
| database\_name | PostgreSQL database name. | `string` | `"appdb"` | no |
| database\_version | Cloud SQL PostgreSQL version. | `string` | `"POSTGRES_15"` | no |
| disk\_size\_gb | Initial SSD size in GB. | `number` | `10` | no |
| instance\_name | Cloud SQL instance name. | `string` | `"tf-example-postgres"` | no |
| region | Cloud SQL region. | `string` | `"asia-northeast1"` | no |
| tier | Cloud SQL machine tier. Shared-core is used to keep the learning sample small. | `string` | `"db-f1-micro"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| connection\_name | Cloud SQL connection name. |
| database\_name | PostgreSQL database name. |
| instance\_name | Cloud SQL instance name. |
| project\_id | Google Cloud Project ID. |
| public\_ip\_address | Public IPv4 address of the instance. No authorized network is configured by this sample. |