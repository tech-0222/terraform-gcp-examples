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
| [google_compute_firewall.allow_iap_ssh_dns](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.allow_iap_ssh_external](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_instance.vm_in_zone](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance) | resource |
| [google_compute_instance.vm_outside_zone](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance) | resource |
| [google_compute_network.dns](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network) | resource |
| [google_compute_network.external](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network) | resource |
| [google_compute_subnetwork.dns](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork) | resource |
| [google_compute_subnetwork.external](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork) | resource |
| [google_dns_managed_zone.private](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dns_managed_zone) | resource |
| [google_dns_record_set.example](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dns_record_set) | resource |
| [google_project_service.compute](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_project_service.dns](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| project\_id | Google Cloud Project ID. | `string` | n/a | yes |
| dns\_name | DNS suffix for the private managed zone. Must end with a dot. | `string` | `"example.internal."` | no |
| external\_network\_name | Name of a separate VPC NOT bound to the private zone. Used to verify that resolution fails from outside the authorized network. | `string` | `"tf-example-dns-external-vpc"` | no |
| external\_subnet\_cidr | Subnet CIDR for the external VPC. | `string` | `"10.31.0.0/24"` | no |
| external\_subnet\_name | Subnet name for the external VPC. | `string` | `"tf-example-dns-external-subnet"` | no |
| machine\_type | Machine type for the verification VMs. | `string` | `"e2-medium"` | no |
| managed\_zone\_name | Cloud DNS managed zone name. | `string` | `"tf-example-private-zone"` | no |
| network\_name | Name of the VPC network used by the private DNS zone. | `string` | `"tf-example-dns-vpc"` | no |
| record\_ip | Private IPv4 address stored in the sample A record. | `string` | `"10.10.0.10"` | no |
| record\_name | Relative name of the sample A record. | `string` | `"app"` | no |
| record\_ttl | TTL of the sample DNS record in seconds. | `number` | `300` | no |
| region | Default region for the provider. | `string` | `"asia-northeast1"` | no |
| subnet\_cidr | Subnet CIDR for the VPC bound to the private zone. | `string` | `"10.30.0.0/24"` | no |
| subnet\_name | Subnet name for the VPC bound to the private zone. | `string` | `"tf-example-dns-subnet"` | no |
| vm\_in\_zone\_name | Name of the VM inside the VPC bound to the private zone. | `string` | `"tf-example-dns-vm-in-zone"` | no |
| vm\_outside\_zone\_name | Name of the VM in the separate VPC, not bound to the private zone. | `string` | `"tf-example-dns-vm-outside-zone"` | no |
| zone | Zone for the verification VMs. | `string` | `"asia-northeast1-a"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| dns\_name | Private DNS suffix. |
| managed\_zone\_name | Cloud DNS managed zone name. |
| network\_name | VPC network name associated with the private DNS zone. |
| record\_fqdn | FQDN of the sample A record. |
| record\_ip | IPv4 address configured in the sample A record. |
| ssh\_in\_zone\_example | Example command to SSH into the VM inside the bound VPC. |
| ssh\_outside\_zone\_example | Example command to SSH into the VM in the separate VPC. |
| vm\_in\_zone\_name | Name of the VM inside the VPC bound to the private zone. |
| vm\_outside\_zone\_name | Name of the VM in the separate VPC, not bound to the private zone. |
| zone | Zone used by the verification VMs. |