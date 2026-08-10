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
| [google_artifact_registry_repository.example](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/artifact_registry_repository) | resource |
| [google_project_service.artifactregistry](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| project\_id | Google Cloud Project ID. | `string` | n/a | yes |
| description | Artifact Registry repository description. | `string` | `"Docker repository for terraform-gcp-examples"` | no |
| region | Default region for the provider. | `string` | `"asia-northeast1"` | no |
| repository\_id | Artifact Registry repository ID. | `string` | `"tf-example-docker"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| docker\_repository\_url | Docker repository hostname/path. |
| repository\_id | Artifact Registry repository ID. |
| repository\_name | Full Artifact Registry repository resource name. |