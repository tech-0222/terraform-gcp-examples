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
| google | 7.46.0 |

## Resources

| Name | Type |
| ---- | ---- |
| [google_compute_address.nat_egress](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_address) | resource |
| [google_compute_firewall.allow_iap_ssh_bastion](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.allow_iap_ssh_gke_nodes](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_instance.bastion](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance) | resource |
| [google_compute_network.vpc](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network) | resource |
| [google_compute_router.nat](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router) | resource |
| [google_compute_router_nat.nat](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router_nat) | resource |
| [google_compute_subnetwork.bastion](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork) | resource |
| [google_compute_subnetwork.gke](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork) | resource |
| [google_container_cluster.primary](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_cluster) | resource |
| [google_container_node_pool.v1](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_node_pool) | resource |
| [google_container_node_pool.v2](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_node_pool) | resource |
| [google_kms_crypto_key.boot_disk](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/kms_crypto_key) | resource |
| [google_kms_crypto_key_iam_member.compute_agent](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/kms_crypto_key_iam_member) | resource |
| [google_kms_crypto_key_iam_member.container_agent](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/kms_crypto_key_iam_member) | resource |
| [google_kms_key_ring.boot_disk](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/kms_key_ring) | resource |
| [google_project_iam_member.bastion_gke](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.compute_viewer](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.gke_node_logging](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.gke_node_monitoring_metric](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.gke_node_monitoring_viewer](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.iap_tunnel](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.os_login](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_service.kms](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_project_service.required](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_service_account.bastion](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [google_service_account.gke_node](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| iap\_member | IAM member granted IAP tunnel access to the bastion (e.g. user:you@example.com). Must match your ADC / gcloud user for verification. | `string` | n/a | yes |
| project\_id | Google Cloud Project ID. | `string` | n/a | yes |
| bastion\_instance\_name | Bastion VM name. | `string` | `"tf-adv-gke-cmek-vm"` | no |
| bastion\_machine\_type | Machine type for the bastion VM. | `string` | `"e2-medium"` | no |
| bastion\_subnet\_cidr | CIDR of the bastion subnet. | `string` | `"10.43.0.0/24"` | no |
| bastion\_subnet\_name | Subnet name for the bastion VM. Kept separate from the GKE subnet so master\_authorized\_networks can allow only this range. | `string` | `"tf-adv-gke-cmek-mgmt-subnet"` | no |
| cluster\_name | GKE cluster name. | `string` | `"tf-adv-gke-cmek"` | no |
| create\_v2\_node\_pool | Create the second node pool. Set to true and re-apply AFTER rotating the key, so its boot disks use the new primary key version. | `bool` | `false` | no |
| gke\_subnet\_cidr | Primary CIDR of the GKE subnet. | `string` | `"10.40.0.0/24"` | no |
| gke\_subnet\_name | Subnet name for GKE nodes. | `string` | `"tf-adv-gke-cmek-subnet"` | no |
| keep\_v1\_node\_pool | Keep the first node pool (created before the key rotation). Set to false and re-apply, after draining, to complete the migration to the new key version. | `bool` | `true` | no |
| kms\_crypto\_key\_name | Cloud KMS crypto key name. Like the key ring, it cannot be deleted -- only its versions can be destroyed. | `string` | `"tf-adv-gke-cmek-boot-disk"` | no |
| kms\_key\_ring\_name | Cloud KMS key ring name. Key rings CANNOT be deleted in Google Cloud -- terraform destroy only drops it from state. Use a different name, or import the existing ring, when re-running this example. | `string` | `"tf-adv-gke-cmek-ring"` | no |
| master\_ipv4\_cidr\_block | CIDR for the private cluster control plane. Must not overlap with any subnet. | `string` | `"172.16.4.0/28"` | no |
| network\_name | VPC network name. | `string` | `"tf-adv-gke-cmek-vpc"` | no |
| node\_count | Nodes per pool. One is enough to observe the key version on the boot disk. | `number` | `1` | no |
| node\_machine\_type | Machine type for both node pools. | `string` | `"e2-medium"` | no |
| pods\_cidr | Secondary CIDR for Pods (VPC-native). | `string` | `"10.41.0.0/16"` | no |
| region | Region for the subnets and the Cloud KMS key ring. The key ring location must match the region the nodes run in. | `string` | `"asia-northeast1"` | no |
| services\_cidr | Secondary CIDR for Services (VPC-native). | `string` | `"10.42.0.0/20"` | no |
| use\_spot | Use Spot nodes to reduce cost. | `bool` | `true` | no |
| zone | Zone for the zonal GKE cluster and the bastion VM. | `string` | `"asia-northeast1-a"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| bastion\_name | Bastion VM name. |
| bastion\_nat\_egress\_ip | Static Cloud NAT egress IP used by the bastion and GKE nodes for outbound traffic. |
| cluster\_name | GKE cluster name. |
| get\_credentials\_example | Example command, run from the bastion, to fetch kubeconfig for the private cluster. |
| kms\_key\_id | Crypto key used for the node boot disks. Both node pools reference this same key. |
| kms\_key\_ring\_name | Key ring name. Cannot be deleted -- reuse or rename it when re-running this example. |
| list\_key\_versions\_example | Command to list key versions and see which one is primary. |
| node\_pool\_names | Node pools that currently exist, driven by keep\_v1\_node\_pool / create\_v2\_node\_pool. |
| private\_endpoint | GKE control plane private endpoint (reachable only from the bastion subnet). |
| project\_id | Google Cloud Project ID. |
| region | Region used by this example. |
| rotate\_key\_example | Command that creates a new key version and makes it primary. Run it before setting create\_v2\_node\_pool = true. |
| ssh\_bastion\_example | Example command to reach the bastion via IAP. |
| zone | Zone of the cluster and the bastion VM. |