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
| [google_project_iam_member.bastion_gke](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.compute_viewer](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.gke_node](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.iap_tunnel](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.os_login](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_service.required](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_service_account.bastion](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [google_service_account.gke_node](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| iap\_member | IAM member granted IAP tunnel access to the bastion (e.g. user:you@example.com). Must match your ADC / gcloud user for verification. | `string` | n/a | yes |
| project\_id | Google Cloud Project ID. | `string` | n/a | yes |
| bastion\_instance\_name | Bastion VM name. | `string` | `"tf-adv-gke-dcc-vm"` | no |
| bastion\_machine\_type | Machine type for the bastion VM. | `string` | `"e2-medium"` | no |
| bastion\_subnet\_cidr | CIDR of the bastion subnet. | `string` | `"10.43.0.0/24"` | no |
| bastion\_subnet\_name | Subnet name for the bastion VM. | `string` | `"tf-adv-gke-dcc-mgmt-subnet"` | no |
| cluster\_name | GKE cluster name. | `string` | `"tf-adv-gke-dcc"` | no |
| default\_compute\_class\_enabled | cluster\_autoscaling.default\_compute\_class\_enabled. The REST API calls it clusterAutoscaling.defaultComputeClassConfig.enabled and the console calls it "Autopilot compute class compatibility". When on, the autoscaler uses the ComputeClass named `default` for workloads that do not select one. This is NOT enable\_autopilot -- the cluster stays Standard. | `bool` | `false` | no |
| enable\_node\_auto\_provisioning | Turn on node auto-provisioning. Without it the autoscaler cannot create node pools, so the compute class has nothing to act on. | `bool` | `true` | no |
| gke\_subnet\_cidr | Primary CIDR of the GKE subnet. | `string` | `"10.40.0.0/24"` | no |
| gke\_subnet\_name | Subnet name for GKE nodes. | `string` | `"tf-adv-gke-dcc-subnet"` | no |
| master\_ipv4\_cidr\_block | CIDR for the private cluster control plane. Must not overlap with any subnet. | `string` | `"172.16.4.0/28"` | no |
| nap\_max\_cpu | Upper bound on vCPUs the autoscaler may provision across the cluster. Keep it small in a test project. | `number` | `12` | no |
| nap\_max\_memory\_gb | Upper bound on memory (GB) the autoscaler may provision across the cluster. | `number` | `48` | no |
| network\_name | VPC network name. | `string` | `"tf-adv-gke-dcc-vpc"` | no |
| node\_count | Nodes in the fixed pool. Anything that does not fit here is what triggers auto-provisioning. | `number` | `1` | no |
| node\_machine\_type | Machine type for the fixed node pool that carries system Pods. | `string` | `"e2-medium"` | no |
| pods\_cidr | Secondary CIDR for Pods (VPC-native). Node auto-provisioning can add node pools, so leave room. | `string` | `"10.41.0.0/16"` | no |
| region | Region for the subnets. | `string` | `"asia-northeast1"` | no |
| services\_cidr | Secondary CIDR for Services (VPC-native). | `string` | `"10.42.0.0/20"` | no |
| use\_spot | Use Spot nodes for the fixed pool to reduce cost. | `bool` | `true` | no |
| zone | Zone for the zonal GKE cluster and the bastion VM. | `string` | `"asia-northeast1-a"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| bastion\_name | Bastion VM name. |
| cluster\_name | GKE cluster name. |
| default\_compute\_class\_enabled\_input | What Terraform was told to set. This is the input, not what GKE reports -- check the cluster itself with the command in show\_cluster\_autoscaling\_example. |
| get\_credentials\_example | Example command, run from the bastion, to fetch kubeconfig for the private cluster. |
| project\_id | Google Cloud Project ID. |
| show\_cluster\_autoscaling\_example | Command that shows what GKE actually stored, including defaultComputeClassConfig. |
| ssh\_bastion\_example | Example command to reach the bastion via IAP. |
| zone | Zone of the cluster and the bastion VM. |