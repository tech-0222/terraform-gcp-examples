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
| [google_compute_backend_service.lb](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_backend_service) | resource |
| [google_compute_firewall.allow_iap_ssh_bastion](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.allow_iap_ssh_gke_nodes](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.allow_lb_health_check](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_global_address.lb_vip](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_global_address) | resource |
| [google_compute_global_forwarding_rule.lb](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_global_forwarding_rule) | resource |
| [google_compute_health_check.lb](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_health_check) | resource |
| [google_compute_instance.bastion](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance) | resource |
| [google_compute_network.vpc](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network) | resource |
| [google_compute_router.nat](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router) | resource |
| [google_compute_router_nat.nat](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router_nat) | resource |
| [google_compute_subnetwork.bastion](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork) | resource |
| [google_compute_subnetwork.gke](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork) | resource |
| [google_compute_target_http_proxy.lb](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_target_http_proxy) | resource |
| [google_compute_url_map.lb](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_url_map) | resource |
| [google_container_cluster.primary](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_cluster) | resource |
| [google_container_node_pool.primary](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_node_pool) | resource |
| [google_project_iam_member.bastion_gke](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.compute_viewer](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.gke_node_logging](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.gke_node_monitoring_metric](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.gke_node_monitoring_viewer](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
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
| app\_port | Port the demo Pods serve on, and the port the NEG exposes. Also opened to Google's health-check ranges in network.tf. | `number` | `80` | no |
| bastion\_instance\_name | Bastion VM name. | `string` | `"tf-adv-gke-negrec-vm"` | no |
| bastion\_machine\_type | Machine type for the bastion VM. | `string` | `"e2-medium"` | no |
| bastion\_subnet\_cidr | CIDR of the bastion subnet. | `string` | `"10.43.0.0/24"` | no |
| bastion\_subnet\_name | Subnet name for the bastion VM. Kept separate from the GKE subnet so master\_authorized\_networks can allow only this range. | `string` | `"tf-adv-gke-negrec-mgmt-subnet"` | no |
| cluster\_name | GKE cluster name. | `string` | `"tf-adv-gke-negrec"` | no |
| enable\_lb | Enable the external Application Load Balancer. Must stay false on the first apply: the backend service reads NEGs that only exist after `kubectl apply`-ing k8s/neg-app.yaml on the running cluster. | `bool` | `false` | no |
| gke\_subnet\_cidr | Primary CIDR of the GKE subnet. | `string` | `"10.40.0.0/24"` | no |
| gke\_subnet\_name | Subnet name for GKE nodes. | `string` | `"tf-adv-gke-negrec-subnet"` | no |
| gke\_zones | Zones the regional GKE node pool spans, one node each. GKE creates one standalone NEG per zone, so 2+ zones make the multi-backend case realistic. | `list(string)` | <pre>[<br/>  "asia-northeast1-a",<br/>  "asia-northeast1-b"<br/>]</pre> | no |
| master\_ipv4\_cidr\_block | CIDR for the private cluster control plane. Must not overlap with any subnet. | `string` | `"172.16.4.0/28"` | no |
| max\_pods\_per\_node | Maximum Pods per node (default\_max\_pods\_per\_node). null leaves it unset, which uses the GKE default (110). Immutable after cluster creation -- changing it requires recreating the node pool. | `number` | `null` | no |
| neg\_name | Name of the standalone NEG. Must match the name in the Service's cloud.google.com/neg annotation (k8s/neg-app.yaml) -- Terraform reads the NEG by this name, it does not create it. | `string` | `"tf-adv-negrec-neg"` | no |
| network\_name | VPC network name. | `string` | `"tf-adv-gke-negrec-vpc"` | no |
| node\_machine\_type | Machine type for the GKE node pool. | `string` | `"e2-small"` | no |
| pods\_cidr | Secondary CIDR for Pods (VPC-native). | `string` | `"10.41.0.0/16"` | no |
| region | Region for the subnets and Artifact Registry. | `string` | `"asia-northeast1"` | no |
| services\_cidr | Secondary CIDR for Services (VPC-native). | `string` | `"10.42.0.0/20"` | no |
| use\_spot | Use Spot nodes to reduce cost. | `bool` | `true` | no |
| zone | Zone for the zonal GKE cluster and the bastion VM. | `string` | `"asia-northeast1-a"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| backend\_service\_name | Backend service that references the standalone NEGs. Inspect it with `gcloud compute backend-services describe/get-health` during the failure and recovery steps. |
| bastion\_name | Bastion VM name. |
| bastion\_nat\_egress\_ip | Static Cloud NAT egress IP used by the bastion and GKE nodes for outbound traffic. |
| cluster\_name | GKE cluster name. |
| get\_credentials\_example | Example command, run from the bastion, to fetch kubeconfig for the private cluster (regional cluster, so --region not --zone). |
| gke\_zones | Zones the GKE node pool spans. GKE creates one standalone NEG per zone. |
| lb\_ip | External LB IP. Only set once enable\_lb=true has been applied. curl it to see 200 (healthy) or 502 (no working backend). |
| neg\_name | Standalone NEG name, as declared in the Service's cloud.google.com/neg annotation. |
| private\_endpoint | GKE control plane private endpoint (reachable only from the bastion subnet). |
| project\_id | Google Cloud Project ID. |
| region | Region used by this example. |
| ssh\_bastion\_example | Example command to reach the bastion via IAP. |
| workload\_pool | Workload Identity pool. Used as PROJECT.svc.id.goog[NAMESPACE/KSA] when binding a KSA to a Google SA. |
| zone | Zone of the bastion VM (the GKE cluster itself is regional; see gke\_zones). |