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
| [google_artifact_registry_repository.app](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/artifact_registry_repository) | resource |
| [google_artifact_registry_repository_iam_member.run_reader](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/artifact_registry_repository_iam_member) | resource |
| [google_cloud_run_v2_service.app](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloud_run_v2_service) | resource |
| [google_cloud_run_v2_service_iam_member.invoker](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloud_run_v2_service_iam_member) | resource |
| [google_cloud_run_v2_service_iam_member.public](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloud_run_v2_service_iam_member) | resource |
| [google_project_iam_member.run_cloudsql_client](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_service.required](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_secret_manager_secret.db_password](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret) | resource |
| [google_secret_manager_secret_iam_member.run_secret_accessor](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret_iam_member) | resource |
| [google_secret_manager_secret_version.db_password](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret_version) | resource |
| [google_service_account.run](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [google_sql_database.app](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/sql_database) | resource |
| [google_sql_database_instance.postgres](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/sql_database_instance) | resource |
| [google_sql_user.app](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/sql_user) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| db\_password | Database password. Store the real value only in local terraform.tfvars. | `string` | n/a | yes |
| project\_id | Google Cloud Project ID. | `string` | n/a | yes |
| allow\_unauthenticated | Allow public unauthenticated invocation. Disabled by default. | `bool` | `false` | no |
| container\_image | Container image for Cloud Run. Start with the public hello image, then replace it with the bundled app image. | `string` | `"us-docker.pkg.dev/cloudrun/container/hello"` | no |
| database\_name | Application database name. | `string` | `"appdb"` | no |
| database\_version | Cloud SQL PostgreSQL version. | `string` | `"POSTGRES_15"` | no |
| db\_password\_version | Version trigger for write-only DB password arguments. Increment when db\_password changes. | `number` | `1` | no |
| db\_user | Built-in PostgreSQL application user. | `string` | `"appuser"` | no |
| disk\_size\_gb | Cloud SQL disk size in GB. | `number` | `10` | no |
| instance\_name | Cloud SQL for PostgreSQL instance name. | `string` | `"tf-adv-run-sql-pg"` | no |
| invoker\_member | Optional authenticated Cloud Run invoker, for example user:you@example.com. Empty disables the binding. | `string` | `""` | no |
| region | Google Cloud region. | `string` | `"asia-northeast1"` | no |
| repository\_id | Artifact Registry Docker repository ID. | `string` | `"tf-adv-run-sql"` | no |
| secret\_id | Secret Manager secret ID used for the DB password. | `string` | `"tf-adv-run-sql-db-password"` | no |
| service\_name | Cloud Run service name. | `string` | `"tf-adv-run-sql"` | no |
| tier | Cloud SQL machine tier. | `string` | `"db-f1-micro"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| app\_image\_example | Suggested image URI for the bundled sample app. |
| curl\_authenticated\_example | Example authenticated request command. |
| database\_name | Application database name. |
| database\_user | Application database user. |
| instance\_connection\_name | Cloud SQL connection name used by Cloud Run. |
| location | Deployment region. |
| project\_id | Google Cloud Project ID. |
| repository\_url | Artifact Registry Docker repository URL. |
| runtime\_service\_account | Cloud Run runtime service account email. |
| secret\_id | Secret Manager secret ID containing the database password. |
| service\_name | Cloud Run service name. |
| service\_url | Cloud Run service URI. |
| sql\_instance\_name | Cloud SQL instance name. |