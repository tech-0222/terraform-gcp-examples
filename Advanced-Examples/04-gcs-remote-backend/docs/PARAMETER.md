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
| [google_project_service.storage](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_storage_bucket.tfstate](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| project\_id | Google Cloud Project ID. | `string` | n/a | yes |
| bucket\_name\_prefix | Prefix for the Terraform state bucket. Final name is <prefix>-<project\_id>. | `string` | `"tf-adv-tfstate"` | no |
| force\_destroy | Allow destroy even when the bucket still has objects (learning sample). | `bool` | `true` | no |
| location | Bucket location. | `string` | `"ASIA-NORTHEAST1"` | no |
| region | Default region for the provider. | `string` | `"asia-northeast1"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| backend\_hcl\_example | Example backend.hcl contents for the demo/ root module. |
| state\_bucket\_name | GCS bucket name for Terraform remote state. |
| state\_bucket\_url | GCS URL of the state bucket. |