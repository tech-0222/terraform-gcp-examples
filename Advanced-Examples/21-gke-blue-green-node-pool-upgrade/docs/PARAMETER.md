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
| [google_container_node_pool.primary](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_node_pool) | resource |
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
| bastion\_instance\_name | Bastion VM name. | `string` | `"tf-adv-gke-bg-vm"` | no |
| bastion\_machine\_type | Machine type for the bastion VM. | `string` | `"e2-medium"` | no |
| bastion\_subnet\_cidr | CIDR of the bastion subnet. | `string` | `"10.43.0.0/24"` | no |
| bastion\_subnet\_name | Subnet name for the bastion VM. | `string` | `"tf-adv-gke-bg-mgmt-subnet"` | no |
| blue\_green\_batch\_percentage | Fraction (0-1, NOT a percent) of nodes moved from blue to green per batch. 0.5 with 2 nodes means one node at a time. | `number` | `0.5` | no |
| blue\_green\_batch\_soak\_duration | Pause between batches. Time to notice a problem before the next batch moves. | `string` | `"60s"` | no |
| cluster\_name | GKE cluster name. | `string` | `"tf-adv-gke-bg"` | no |
| gke\_subnet\_cidr | Primary CIDR of the GKE subnet. | `string` | `"10.40.0.0/24"` | no |
| gke\_subnet\_name | Subnet name for GKE nodes. | `string` | `"tf-adv-gke-bg-subnet"` | no |
| kms\_crypto\_key\_name | Cloud KMS crypto key name. Like the key ring, it cannot be deleted. | `string` | `"tf-adv-gke-bg-boot-disk"` | no |
| kms\_key\_ring\_name | Cloud KMS key ring name. Key rings CANNOT be deleted in Google Cloud, and terraform destroy schedules the key versions for destruction -- use a fresh name when re-running this example. | `string` | `"tf-adv-gke-bg-ring"` | no |
| master\_ipv4\_cidr\_block | CIDR for the private cluster control plane. Must not overlap with any subnet. | `string` | `"172.16.4.0/28"` | no |
| master\_version | Control plane version at creation. Must be NEWER than node\_pool\_version, otherwise there is nothing for the node pool to upgrade to. Versions age out of a channel, so check availability before applying. | `string` | `"1.35.7-gke.1150000"` | no |
| network\_name | VPC network name. | `string` | `"tf-adv-gke-bg-vpc"` | no |
| node\_count | Nodes in the pool. Two is the minimum that shows batching, and a BLUE\_GREEN upgrade briefly doubles this -- budget for 2x. | `number` | `2` | no |
| node\_machine\_type | Machine type for the node pool. | `string` | `"e2-medium"` | no |
| node\_pool\_soak\_duration | How long the blue node pool is kept after the workload has moved to green. This is the rollback window: once it expires blue is deleted and rollback is no longer possible. GKE's default is 3600s; this example uses a short value so the whole cycle finishes in one sitting. | `string` | `"600s"` | no |
| node\_pool\_version | Node pool version at creation. Deliberately older than master\_version. The upgrade to master\_version is triggered with gcloud, not Terraform, so `version` is in lifecycle.ignore\_changes. | `string` | `"1.35.7-gke.1027000"` | no |
| pods\_cidr | Secondary CIDR for Pods (VPC-native). Sized for the doubled node count during a BLUE\_GREEN upgrade. | `string` | `"10.41.0.0/16"` | no |
| region | Region for the subnets and the Cloud KMS key ring. | `string` | `"asia-northeast1"` | no |
| release\_channel | GKE release channel. Both master\_version and node\_pool\_version must be valid versions in this channel -- check with `gcloud container get-server-config`. | `string` | `"REGULAR"` | no |
| services\_cidr | Secondary CIDR for Services (VPC-native). | `string` | `"10.42.0.0/20"` | no |
| use\_spot | Use Spot nodes to reduce cost. | `bool` | `true` | no |
| zone | Zone for the zonal GKE cluster and the bastion VM. | `string` | `"asia-northeast1-a"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| bastion\_name | Bastion VM name. |
| cluster\_name | GKE cluster name. |
| get\_credentials\_example | Example command, run from the bastion, to fetch kubeconfig for the private cluster. |
| kms\_key\_id | Crypto key used for the node boot disks. |
| master\_version | Control plane version. The node pool upgrades to this. |
| node\_pool\_name | Node pool that carries the BLUE\_GREEN upgrade settings. |
| project\_id | Google Cloud Project ID. |
| region | Region used by this example. |
| rollback\_node\_pool\_example | Command that rolls the upgrade back. Only works while blue still exists, i.e. before node\_pool\_soak\_duration expires. |
| show\_upgrade\_settings\_example | Command to confirm the BLUE\_GREEN settings landed in GKE. |
| ssh\_bastion\_example | Example command to reach the bastion via IAP. |
| upgrade\_node\_pool\_example | Command that starts the BLUE\_GREEN upgrade. Run it after the initial apply. |
| zone | Zone of the cluster and the bastion VM. |