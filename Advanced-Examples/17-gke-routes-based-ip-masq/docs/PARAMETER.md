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
| google.b | 7.46.0 |

## Resources

| Name | Type |
| ---- | ---- |
| [google_compute_address.a_nat_egress](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_address) | resource |
| [google_compute_address.b_nat_egress](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_address) | resource |
| [google_compute_firewall.allow_iap_ssh_bastion](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.allow_iap_ssh_gke_nodes](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.b_allow_http_from_a_nodes](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.b_allow_iap_ssh](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_instance.bastion](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance) | resource |
| [google_compute_instance.target_vm](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance) | resource |
| [google_compute_network.vpc_a](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network) | resource |
| [google_compute_network.vpc_b](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network) | resource |
| [google_compute_network_peering.a_to_b](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network_peering) | resource |
| [google_compute_network_peering.b_to_a](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network_peering) | resource |
| [google_compute_router.a_nat](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router) | resource |
| [google_compute_router.b_nat](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router) | resource |
| [google_compute_router_nat.a_nat](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router_nat) | resource |
| [google_compute_router_nat.b_nat](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router_nat) | resource |
| [google_compute_subnetwork.bastion](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork) | resource |
| [google_compute_subnetwork.gke](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork) | resource |
| [google_compute_subnetwork.target](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork) | resource |
| [google_container_cluster.primary](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_cluster) | resource |
| [google_container_node_pool.primary](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_node_pool) | resource |
| [google_project_iam_member.b_compute_viewer](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.b_iap_tunnel](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.b_os_login](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.bastion_gke](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.compute_viewer](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.gke_node_logging](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.gke_node_monitoring_metric](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.gke_node_monitoring_viewer](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.iap_tunnel](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.os_login](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_service.a_required](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_project_service.b_required](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_service_account.bastion](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [google_service_account.gke_node](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| iap\_member | IAM member granted IAP tunnel access to the bastion and the target VM (e.g. user:you@example.com). Must match your ADC / gcloud user for verification. Granted in both projects. | `string` | n/a | yes |
| project\_id | Project A: Google Cloud Project ID hosting the GKE cluster and bastion. | `string` | n/a | yes |
| target\_project\_id | Project B: Google Cloud Project ID hosting the destination VM. Must be a different project than project\_id for the cross-project VPC Peering to be meaningful. | `string` | n/a | yes |
| bastion\_instance\_name | Bastion VM name. | `string` | `"tf-adv-gke-ipmasq-bastion"` | no |
| bastion\_machine\_type | Machine type for the bastion VM. | `string` | `"e2-medium"` | no |
| bastion\_subnet\_cidr | CIDR of the bastion subnet in Project A. | `string` | `"10.10.1.0/28"` | no |
| cluster\_name | GKE cluster name. | `string` | `"tf-adv-gke-ipmasq"` | no |
| gke\_subnet\_cidr | Primary CIDR of the GKE node subnet in Project A. | `string` | `"10.10.0.0/28"` | no |
| master\_ipv4\_cidr\_block | CIDR for the private cluster control plane. Must not overlap with any subnet or with pod\_cidr/services\_cidr. | `string` | `"192.168.255.0/28"` | no |
| network\_a\_name | Project A VPC network name. | `string` | `"tf-adv-gke-ipmasq-a-vpc"` | no |
| network\_b\_name | Project B VPC network name. | `string` | `"tf-adv-gke-ipmasq-b-vpc"` | no |
| node\_machine\_type | Machine type for the GKE node pool. e2-small (2GB) is not enough -- the Konnectivity Agent's memory request leaves it Pending. e2-standard-2 (8GB) is the smallest machine type observed to work reliably. | `string` | `"e2-standard-2"` | no |
| peering\_custom\_routes | Whether the VPC Peering exports/imports custom routes. false (the default) means Project B never learns a route to pod\_cidr, so Pod-IP-sourced traffic to the target VM cannot get a return path -- this is the failure this example reproduces and then works around with ip-masq-agent, without ever setting this to true. | `bool` | `false` | no |
| pod\_cidr | Pod CIDR for the routes-based cluster. This is a VPC custom route once the cluster exists, not a subnet secondary range -- that's the entire point of this example. | `string` | `"172.16.0.0/16"` | no |
| region | Region for both projects' subnets. | `string` | `"asia-northeast1"` | no |
| services\_cidr | Service CIDR for the routes-based cluster. | `string` | `"172.17.0.0/20"` | no |
| target\_subnet\_cidr | CIDR of the destination VM's subnet in Project B. | `string` | `"10.20.0.0/24"` | no |
| target\_vm\_ip | Static internal IP for the destination VM, inside target\_subnet\_cidr. | `string` | `"10.20.0.10"` | no |
| target\_vm\_machine\_type | Machine type for the destination VM. | `string` | `"e2-medium"` | no |
| target\_vm\_name | Destination VM name in Project B. | `string` | `"tf-adv-gke-ipmasq-target-vm"` | no |
| use\_spot | Use Spot for the GKE node and the target VM to reduce cost. | `bool` | `true` | no |
| zone | Zone for the zonal GKE cluster, the bastion VM, and the target VM. | `string` | `"asia-northeast1-a"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| bastion\_name | Bastion VM name (Project A). |
| cluster\_name | GKE cluster name. |
| get\_credentials\_example | Example command, run from the bastion, to fetch kubeconfig for the private cluster. |
| peering\_custom\_routes | Whether the VPC Peering exports/imports custom routes (false = Project B never learns a route to pod\_cidr). |
| pod\_cidr | Pod CIDR. On this routes-based cluster it is a VPC custom route, not a subnet secondary range. |
| project\_id | Project A: Google Cloud Project ID (GKE + bastion). |
| region | Region used by this example. |
| ssh\_bastion\_example | Example command to reach the bastion via IAP. |
| ssh\_target\_vm\_example | Example command to reach the target VM via IAP (for tcpdump during verification). |
| target\_project\_id | Project B: Google Cloud Project ID (destination VM). |
| target\_vm\_ip | Destination VM's internal IP -- the curl target from inside the cluster. |
| target\_vm\_name | Destination VM name (Project B). |
| zone | Zone of the cluster, the bastion VM, and the target VM. |