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
| [google_artifact_registry_repository.docker](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/artifact_registry_repository) | resource |
| [google_artifact_registry_repository_iam_member.gke_node_reader](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/artifact_registry_repository_iam_member) | resource |
| [google_compute_address.ilb_vip](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_address) | resource |
| [google_compute_address.nat_egress](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_address) | resource |
| [google_compute_firewall.allow_iap_ssh_bastion](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.allow_iap_ssh_gke_nodes](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.allow_ilb_health_check](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.allow_ilb_proxies](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_forwarding_rule.fr_81](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_forwarding_rule) | resource |
| [google_compute_forwarding_rule.fr_82](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_forwarding_rule) | resource |
| [google_compute_forwarding_rule.fr_83](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_forwarding_rule) | resource |
| [google_compute_instance.bastion](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance) | resource |
| [google_compute_network.vpc](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network) | resource |
| [google_compute_region_backend_service.bs_app_a](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_backend_service) | resource |
| [google_compute_region_backend_service.bs_app_b](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_backend_service) | resource |
| [google_compute_region_backend_service.bs_app_c](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_backend_service) | resource |
| [google_compute_region_health_check.hc_app_a](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_health_check) | resource |
| [google_compute_region_health_check.hc_app_b](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_health_check) | resource |
| [google_compute_region_health_check.hc_app_c](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_health_check) | resource |
| [google_compute_region_target_http_proxy.http_proxy_81](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_target_http_proxy) | resource |
| [google_compute_region_target_http_proxy.http_proxy_82](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_target_http_proxy) | resource |
| [google_compute_region_target_http_proxy.http_proxy_83](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_target_http_proxy) | resource |
| [google_compute_region_url_map.urlmap_81](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_url_map) | resource |
| [google_compute_region_url_map.urlmap_82](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_url_map) | resource |
| [google_compute_region_url_map.urlmap_83](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_url_map) | resource |
| [google_compute_router.nat](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router) | resource |
| [google_compute_router_nat.nat](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router_nat) | resource |
| [google_compute_subnetwork.bastion](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork) | resource |
| [google_compute_subnetwork.gke](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork) | resource |
| [google_compute_subnetwork.proxy_only](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork) | resource |
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
| artifact\_registry\_repository\_id | Artifact Registry Docker repository ID. | `string` | `"tf-adv-gke-ilbneg-repo"` | no |
| bastion\_instance\_name | Bastion VM name. | `string` | `"tf-adv-gke-ilbneg-vm"` | no |
| bastion\_machine\_type | Machine type for the bastion VM. | `string` | `"e2-medium"` | no |
| bastion\_subnet\_cidr | CIDR of the bastion subnet. | `string` | `"10.43.0.0/24"` | no |
| bastion\_subnet\_name | Subnet name for the bastion VM. Kept separate from the GKE subnet so master\_authorized\_networks can allow only this range. | `string` | `"tf-adv-gke-ilbneg-mgmt-subnet"` | no |
| cluster\_name | GKE cluster name. | `string` | `"tf-adv-gke-ilbneg"` | no |
| enable\_ilb | Enable the Internal HTTP LB resources. Must stay false on the first apply: the backend services reference NEGs (neg-app-a/b/c) that only exist after `kubectl apply`-ing k8s/ilb-app-*.yaml on the already-created cluster. Set to true and re-apply once those NEGs exist. | `bool` | `false` | no |
| gke\_subnet\_cidr | Primary CIDR of the GKE subnet. | `string` | `"10.40.0.0/24"` | no |
| gke\_subnet\_name | Subnet name for GKE nodes. | `string` | `"tf-adv-gke-ilbneg-subnet"` | no |
| gke\_zones | Zones the GKE node pool spans, one node each. Each zone gets its own NEG once app-a/b/c are deployed, so this needs 2+ zones to demonstrate multi-zone backends. | `list(string)` | <pre>[<br/>  "asia-northeast1-a",<br/>  "asia-northeast1-b",<br/>  "asia-northeast1-c"<br/>]</pre> | no |
| ilb\_proxy\_subnet\_cidr | CIDR for the proxy-only subnet required by INTERNAL\_MANAGED load balancing. Must not overlap with any other subnet or the control plane CIDR. | `string` | `"10.44.0.0/23"` | no |
| ilb\_vip\_address | Internal HTTP LB shared VIP, an address inside the GKE subnet. Chosen near the top of the range (not .1/.2) to avoid colliding with node internal IPs, which are already assigned by the time this address is reserved (nodes are created before enable\_ilb=true). | `string` | `"10.40.0.250"` | no |
| master\_ipv4\_cidr\_block | CIDR for the private cluster control plane. Must not overlap with any subnet. | `string` | `"172.16.4.0/28"` | no |
| network\_name | VPC network name. | `string` | `"tf-adv-gke-ilbneg-vpc"` | no |
| node\_machine\_type | Machine type for the GKE node pool. | `string` | `"e2-small"` | no |
| pods\_cidr | Secondary CIDR for Pods (VPC-native). | `string` | `"10.41.0.0/16"` | no |
| region | Region for the subnets and Artifact Registry. | `string` | `"asia-northeast1"` | no |
| services\_cidr | Secondary CIDR for Services (VPC-native). | `string` | `"10.42.0.0/20"` | no |
| use\_spot | Use Spot nodes to reduce cost. | `bool` | `true` | no |
| zone | Zone for the bastion VM. The GKE cluster is regional; see gke\_zones for the node pool's zones. | `string` | `"asia-northeast1-a"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| artifact\_registry\_nginx\_image | Full URL for the nginx image used in the verification step. |
| artifact\_registry\_repository\_url | Artifact Registry Docker repository URL (docker push/pull base). |
| bastion\_name | Bastion VM name. |
| bastion\_nat\_egress\_ip | Static Cloud NAT egress IP used by the bastion and GKE nodes for outbound traffic. |
| cluster\_name | GKE cluster name. |
| get\_credentials\_example | Example command, run from the bastion, to fetch kubeconfig for the private cluster (regional cluster, so --region not --zone). |
| gke\_zones | Zones the GKE node pool spans, one node each (one NEG per zone once app-a/b/c are deployed). |
| ilb\_vip | Internal HTTP LB shared VIP. Only set once enable\_ilb=true has been applied. curl :81/:82/:83 from the bastion to reach app-a/b/c. |
| private\_endpoint | GKE control plane private endpoint (reachable only from the bastion subnet). |
| project\_id | Google Cloud Project ID. |
| region | Region used by this example. |
| ssh\_bastion\_example | Example command to reach the bastion via IAP. |
| workload\_pool | Workload Identity pool. Used as PROJECT.svc.id.goog[NAMESPACE/KSA] when binding a KSA to a Google SA. |
| zone | Zone of the bastion VM (the GKE cluster itself is regional; see gke\_zones). |