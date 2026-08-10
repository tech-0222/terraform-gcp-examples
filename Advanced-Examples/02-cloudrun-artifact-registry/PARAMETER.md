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
| [google_artifact_registry_repository.app](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/artifact_registry_repository) | resource |
| [google_artifact_registry_repository_iam_member.run_reader](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/artifact_registry_repository_iam_member) | resource |
| [google_cloud_run_v2_service.hello](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloud_run_v2_service) | resource |
| [google_cloud_run_v2_service_iam_member.invoker](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloud_run_v2_service_iam_member) | resource |
| [google_cloud_run_v2_service_iam_member.public](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloud_run_v2_service_iam_member) | resource |
| [google_project_service.required](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_service_account.run](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| project\_id | Google Cloud Project ID. | `string` | n/a | yes |
| allow\_unauthenticated | If true, grant roles/run.invoker to allUsers (not recommended for this advanced sample). | `bool` | `false` | no |
| container\_image | Container image URL. Prefer an image in this project's Artifact Registry after push. | `string` | `"us-docker.pkg.dev/cloudrun/container/hello"` | no |
| invoker\_member | IAM member granted roles/run.invoker (e.g. user:you@example.com). Empty skips the binding. | `string` | `""` | no |
| region | Region for Artifact Registry and Cloud Run. | `string` | `"asia-northeast1"` | no |
| repository\_id | Artifact Registry repository ID. | `string` | `"tf-adv-run"` | no |
| service\_name | Cloud Run service name. | `string` | `"tf-adv-hello"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| curl\_authenticated\_example | Example authenticated request (requires roles/run.invoker). |
| example\_ar\_image | Example image path after pushing hello into Artifact Registry. |
| location | Cloud Run location. |
| repository\_id | Artifact Registry repository ID. |
| repository\_url | Docker repository host/path prefix (without image name). |
| runtime\_service\_account\_email | Cloud Run runtime service account email. |
| service\_name | Cloud Run service name. |
| uri | Cloud Run service URI. |