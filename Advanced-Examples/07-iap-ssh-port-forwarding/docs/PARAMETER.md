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
| google | 7.44.0 |

## Resources

| Name | Type |
| ---- | ---- |
| [google_compute_firewall.allow_iap_ssh](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_instance.vm](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance) | resource |
| [google_compute_network.vpc](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network) | resource |
| [google_compute_router.router](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router) | resource |
| [google_compute_router_nat.nat](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router_nat) | resource |
| [google_compute_subnetwork.primary](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork) | resource |
| [google_iap_tunnel_instance_iam_member.ssh](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/iap_tunnel_instance_iam_member) | resource |
| [google_project_iam_member.iap_tunnel](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.os_login](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_service.required](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_service_account.vm](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| iap\_member | IAM member granted IAP tunnel and OS Login (for example, user:you@example.com). | `string` | n/a | yes |
| project\_id | Google Cloud Project ID. | `string` | n/a | yes |
| instance\_name | Compute Engine instance name. | `string` | `"tf-adv-iap-forward-vm"` | no |
| local\_port | Local IPv4 port used by the generated SSH forwarding command. | `number` | `8080` | no |
| machine\_type | Machine type for the short-lived test VM. | `string` | `"e2-small"` | no |
| network\_name | VPC network name. | `string` | `"tf-adv-iap-forward-vpc"` | no |
| region | Region for the subnet, Cloud Router, and Cloud NAT. | `string` | `"asia-northeast1"` | no |
| subnet\_cidr | Subnet primary IPv4 CIDR. | `string` | `"10.70.0.0/24"` | no |
| subnet\_name | Subnet name. | `string` | `"tf-adv-iap-forward-subnet"` | no |
| zone | Zone for the test VM. | `string` | `"asia-northeast1-a"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| http\_check\_command | Command to verify the forwarded HTTP endpoint from another terminal. |
| http\_tunnel\_command | Command to forward local IPv4 port to nginx through IAP and SSH. |
| iap\_ssh\_command | Command to open an interactive SSH session through IAP. |
| instance\_name | VM instance name. |
| internal\_ip | VM internal IPv4 address. |
| project\_id | Google Cloud Project ID. |
| zone | VM zone. |