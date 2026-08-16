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
| [google_compute_firewall.allow_iap_ssh](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_instance.vm](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance) | resource |
| [google_compute_network.vpc](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network) | resource |
| [google_compute_subnetwork.primary](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork) | resource |
| [google_iap_tunnel_instance_iam_member.ssh](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/iap_tunnel_instance_iam_member) | resource |
| [google_project_iam_member.iap_tunnel](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.os_login](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_service.required](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_service_account.vm](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| iap\_member | IAM member granted IAP tunnel + OS Login (e.g. user:you@example.com). | `string` | n/a | yes |
| project\_id | Google Cloud Project ID. | `string` | n/a | yes |
| instance\_name | Compute Engine instance name. | `string` | `"tf-adv-gce-iap-01"` | no |
| machine\_type | Machine type. e2-medium or larger is recommended for general utility. | `string` | `"e2-medium"` | no |
| network\_name | VPC network name. | `string` | `"tf-adv-gce-iap-vpc"` | no |
| region | Region for the subnet. | `string` | `"asia-northeast1"` | no |
| subnet\_cidr | Subnet CIDR. | `string` | `"10.30.0.0/24"` | no |
| subnet\_name | Subnet name. | `string` | `"tf-adv-gce-iap-subnet"` | no |
| zone | Zone for the VM. | `string` | `"asia-northeast1-a"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| iap\_member | Principal granted IAP tunnel + OS Login. |
| instance\_name | VM instance name. |
| internal\_ip | VM internal IP address. |
| network\_name | VPC network name. |
| ssh\_via\_iap\_example | Example command to SSH via IAP. |
| vm\_service\_account\_email | Runtime service account email attached to the VM. |
| zone | VM zone. |