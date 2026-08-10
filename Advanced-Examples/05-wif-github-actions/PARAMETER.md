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
| [google_iam_workload_identity_pool.github](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/iam_workload_identity_pool) | resource |
| [google_iam_workload_identity_pool_provider.github](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/iam_workload_identity_pool_provider) | resource |
| [google_project_service.required](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_service_account.github](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [google_service_account_iam_member.wif](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account_iam_member) | resource |
| [google_storage_bucket.demo](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket) | resource |
| [google_storage_bucket_iam_member.demo_viewer](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_iam_member) | resource |
| [google_storage_bucket_object.hello](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_object) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| project\_id | Google Cloud Project ID. | `string` | n/a | yes |
| demo\_bucket\_prefix | Prefix for a tiny bucket used to demonstrate least-privilege access from GHA. | `string` | `"tf-adv-wif-demo"` | no |
| github\_repository | GitHub repository allowed to impersonate the SA (org/repo). | `string` | `"tech-0222/terraform-gcp-examples"` | no |
| pool\_id | Workload Identity Pool ID. | `string` | `"tf-adv-github-pool"` | no |
| provider\_id | Workload Identity Pool Provider ID (GitHub OIDC). | `string` | `"tf-adv-github-provider"` | no |
| region | Default region for the provider. | `string` | `"asia-northeast1"` | no |
| service\_account\_id | Service Account ID used by GitHub Actions via WIF. | `string` | `"tf-adv-github-actions"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| auth\_action\_inputs\_example | Example inputs for google-github-actions/auth. |
| demo\_bucket\_name | Demo bucket the workflow can list/read. |
| github\_repository | GitHub repository allowed by attribute\_condition / IAM principalSet. |
| project\_number | Project number (needed in WIF provider resource name). |
| service\_account\_email | Service account email for GitHub Actions. |
| workload\_identity\_pool\_id | Full Workload Identity Pool resource name. |
| workload\_identity\_provider\_name | Full WIF provider resource name for google-github-actions/auth. |