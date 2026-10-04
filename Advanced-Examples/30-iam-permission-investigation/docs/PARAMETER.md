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
| google | 7.46.1 |

## Resources

| Name | Type |
| ---- | ---- |
| [google_compute_network.lab](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network) | resource |
| [google_compute_subnetwork.lab](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork) | resource |
| [google_project_iam_custom_role.create_only](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_custom_role) | resource |
| [google_project_iam_member.console](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.subject_compute](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.terraform_compute](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_service.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_service_account.subject](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [google_service_account.terraform](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [google_service_account.vm_runtime](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [google_service_account_iam_member.operator_impersonate](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account_iam_member) | resource |
| [google_service_account_iam_member.subject_act_as_runtime](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account_iam_member) | resource |
| [google_service_account_iam_member.terraform_act_as_runtime](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account_iam_member) | resource |
| [google_storage_bucket.lab](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket) | resource |
| [google_storage_bucket_iam_member.console](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_iam_member) | resource |
| [google_storage_bucket_iam_member.subject](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_iam_member) | resource |
| [google_storage_bucket_object.hello](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_object) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| operator\_member | 検証用 SA を借用して操作する人の IAM メンバー（例: user:you@example.com）。Owner でも SA の借用には Token Creator が要る | `string` | n/a | yes |
| project\_id | 検証に使う Google Cloud プロジェクト ID | `string` | n/a | yes |
| console\_bucket\_role | console\_member にバケット単位で付与する Role。空なら付与しない | `string` | `""` | no |
| console\_member | Console の権限差を確かめる専用ユーザー（例: user:iam-lab@example.com）。空なら Console 検証用の付与をしない。普段使いの強い権限を持つユーザーを指定しない | `string` | `""` | no |
| console\_project\_role | console\_member にプロジェクト単位で付与する Role。空なら付与しない（Console でバケット一覧を出すための追加権限の検証に使う） | `string` | `""` | no |
| create\_only\_extra\_permissions | create\_only ロールに compute.instances.create 以外で足す Permission。エラーに出たものを1つずつ足す | `list(string)` | `[]` | no |
| network\_name | n/a | `string` | `"tf-adv-iam-vpc"` | no |
| region | n/a | `string` | `"asia-northeast1"` | no |
| subject\_bucket\_role | tf-adv-iam-subject にバケット単位で付与する Role。空なら付与しない | `string` | `""` | no |
| subject\_can\_act\_as\_runtime | tf-adv-iam-subject に、Runtime SA に対する roles/iam.serviceAccountUser を付与するか | `bool` | `false` | no |
| subject\_compute\_role | tf-adv-iam-subject にプロジェクト単位で付与する Compute の Role。none / create\_only（compute.instances.create だけのカスタムロール）/ instance\_admin（roles/compute.instanceAdmin.v1） | `string` | `"none"` | no |
| subnet\_cidr | n/a | `string` | `"10.30.0.0/24"` | no |
| terraform\_can\_act\_as\_runtime | tf-adv-iam-terraform に、Runtime SA に対する roles/iam.serviceAccountUser を付与するか | `bool` | `false` | no |
| terraform\_compute\_role | tf-adv-iam-terraform にプロジェクト単位で付与する Compute の Role。none / create\_only / instance\_admin | `string` | `"none"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| bucket | n/a |
| create\_only\_role | n/a |
| subject\_sa | n/a |
| subnet | n/a |
| terraform\_sa | n/a |
| vm\_runtime\_sa | n/a |