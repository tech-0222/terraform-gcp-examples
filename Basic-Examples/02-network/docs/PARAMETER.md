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
| [google_compute_firewall.allow_internal](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_network.vpc](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network) | resource |
| [google_compute_subnetwork.primary](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork) | resource |
| [google_project_service.compute](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| project\_id | Google Cloud Project ID. | `string` | n/a | yes |
| network\_name | VPC network name. | `string` | `"tf-example-vpc"` | no |
| region | Region for the subnet. | `string` | `"asia-northeast1"` | no |
| subnet\_cidr | Primary IPv4 CIDR for the subnet. | `string` | `"10.10.0.0/24"` | no |
| subnet\_name | Subnet name. | `string` | `"tf-example-subnet"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| firewall\_names | Firewall rule names created by this sample. |
| network\_id | VPC network ID. |
| network\_name | VPC network name. |
| network\_self\_link | VPC network self link. |
| subnet\_cidr | Subnet primary CIDR. |
| subnet\_id | Subnet ID. |
| subnet\_name | Subnet name. |