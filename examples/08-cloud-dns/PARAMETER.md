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
| [google_compute_network.dns](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network) | resource |
| [google_dns_managed_zone.private](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dns_managed_zone) | resource |
| [google_dns_record_set.example](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dns_record_set) | resource |
| [google_project_service.compute](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_project_service.dns](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| project\_id | Google Cloud Project ID. | `string` | n/a | yes |
| dns\_name | DNS suffix for the private managed zone. Must end with a dot. | `string` | `"example.internal."` | no |
| managed\_zone\_name | Cloud DNS managed zone name. | `string` | `"tf-example-private-zone"` | no |
| network\_name | Name of the VPC network used by the private DNS zone. | `string` | `"tf-example-dns-vpc"` | no |
| record\_ip | Private IPv4 address stored in the sample A record. | `string` | `"10.10.0.10"` | no |
| record\_name | Relative name of the sample A record. | `string` | `"app"` | no |
| record\_ttl | TTL of the sample DNS record in seconds. | `number` | `300` | no |
| region | Default region for the provider. | `string` | `"asia-northeast1"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| dns\_name | Private DNS suffix. |
| managed\_zone\_name | Cloud DNS managed zone name. |
| network\_name | VPC network name associated with the private DNS zone. |
| record\_fqdn | FQDN of the sample A record. |
| record\_ip | IPv4 address configured in the sample A record. |