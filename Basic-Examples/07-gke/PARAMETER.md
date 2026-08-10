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
| [google_compute_network.vpc](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network) | resource |
| [google_compute_subnetwork.primary](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork) | resource |
| [google_container_cluster.primary](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_cluster) | resource |
| [google_container_node_pool.spot](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_node_pool) | resource |
| [google_project_service.required](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| project\_id | Google Cloud Project ID. | `string` | n/a | yes |
| cluster\_name | GKE cluster name. | `string` | `"tf-example-gke"` | no |
| machine\_type | Node machine type. | `string` | `"e2-medium"` | no |
| network\_name | VPC network name. | `string` | `"tf-example-gke-vpc"` | no |
| node\_count | Number of nodes in the Spot node pool. | `number` | `1` | no |
| pods\_cidr | Secondary CIDR for Pods. | `string` | `"10.41.0.0/16"` | no |
| region | Region for the subnet. | `string` | `"asia-northeast1"` | no |
| services\_cidr | Secondary CIDR for Services. | `string` | `"10.42.0.0/20"` | no |
| subnet\_cidr | Primary subnet CIDR. | `string` | `"10.40.0.0/24"` | no |
| subnet\_name | Subnet name. | `string` | `"tf-example-gke-subnet"` | no |
| zone | Zone for the zonal GKE cluster. | `string` | `"asia-northeast1-a"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| cluster\_endpoint | GKE API endpoint. |
| cluster\_location | GKE cluster location (zone). |
| cluster\_name | GKE cluster name. |
| get\_credentials\_example | Example command to fetch kubeconfig. |
| network\_name | VPC network name. |