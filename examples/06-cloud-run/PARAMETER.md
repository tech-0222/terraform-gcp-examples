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
| [google_cloud_run_v2_service.hello](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloud_run_v2_service) | resource |
| [google_cloud_run_v2_service_iam_member.public](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloud_run_v2_service_iam_member) | resource |
| [google_project_service.required](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| project\_id | Google Cloud Project ID. | `string` | n/a | yes |
| allow\_unauthenticated | If true, grant roles/run.invoker to allUsers (public access). | `bool` | `true` | no |
| container\_image | Container image URL. | `string` | `"us-docker.pkg.dev/cloudrun/container/hello"` | no |
| region | Region for the Cloud Run service. | `string` | `"asia-northeast1"` | no |
| service\_name | Cloud Run service name. | `string` | `"tf-example-hello"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| location | Cloud Run location. |
| service\_name | Cloud Run service name. |
| uri | Cloud Run service URI. |