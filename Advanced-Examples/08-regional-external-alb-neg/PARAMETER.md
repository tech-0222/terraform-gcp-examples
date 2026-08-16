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
| [google_compute_address.be](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_address) | resource |
| [google_compute_address.vip](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_address) | resource |
| [google_compute_firewall.allow_health_check](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.allow_iap_ssh](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.allow_proxies](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_forwarding_rule.fr_81](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_forwarding_rule) | resource |
| [google_compute_forwarding_rule.fr_82](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_forwarding_rule) | resource |
| [google_compute_instance.be](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance) | resource |
| [google_compute_network.vpc](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network) | resource |
| [google_compute_network_endpoint.ep_a](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network_endpoint) | resource |
| [google_compute_network_endpoint.ep_a2](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network_endpoint) | resource |
| [google_compute_network_endpoint.ep_b](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network_endpoint) | resource |
| [google_compute_network_endpoint_group.neg_a](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network_endpoint_group) | resource |
| [google_compute_network_endpoint_group.neg_b](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network_endpoint_group) | resource |
| [google_compute_region_backend_service.bs_a](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_backend_service) | resource |
| [google_compute_region_backend_service.bs_b](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_backend_service) | resource |
| [google_compute_region_health_check.hc_a](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_health_check) | resource |
| [google_compute_region_health_check.hc_b](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_health_check) | resource |
| [google_compute_region_target_http_proxy.proxy_81](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_target_http_proxy) | resource |
| [google_compute_region_target_http_proxy.proxy_82](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_target_http_proxy) | resource |
| [google_compute_region_url_map.urlmap_81](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_url_map) | resource |
| [google_compute_region_url_map.urlmap_82](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_url_map) | resource |
| [google_compute_router.router](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router) | resource |
| [google_compute_router_nat.nat](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router_nat) | resource |
| [google_compute_subnetwork.proxy_only](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork) | resource |
| [google_compute_subnetwork.workload](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork) | resource |
| [google_project_service.required](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| project\_id | Google Cloud Project ID. | `string` | n/a | yes |
| machine\_type | Backend VM machine type. e2-micro is enough for a static HTTP identity. | `string` | `"e2-micro"` | no |
| network\_name | VPC network name. | `string` | `"tf-adv-elb08-vpc"` | no |
| proxy\_subnet\_cidr | Proxy-only subnet CIDR. Regional managed proxy typically needs at least /23. | `string` | `"10.128.0.0/23"` | no |
| proxy\_subnet\_name | Proxy-only subnet name (required for regional Envoy ALB). | `string` | `"tf-adv-elb08-proxy"` | no |
| region | Region for the regional external Application Load Balancer. | `string` | `"asia-northeast1"` | no |
| subnet\_cidr | Workload subnet CIDR. | `string` | `"10.80.0.0/24"` | no |
| subnet\_name | Workload subnet name. | `string` | `"tf-adv-elb08-subnet"` | no |
| zone\_a | Zone for backend-a / backend-a2. | `string` | `"asia-northeast1-a"` | no |
| zone\_c | Zone for backend-b. | `string` | `"asia-northeast1-c"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| curl\_port\_81 | Expect backend-a or backend-a2. |
| curl\_port\_82 | Expect backend-b. |
| project\_id | Google Cloud Project ID. |
| vip | Regional external Application Load Balancer VIP. |