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
| [google_compute_forwarding_rule.fr](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_forwarding_rule) | resource |
| [google_compute_instance.be](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance) | resource |
| [google_compute_instance.deny_client](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance) | resource |
| [google_compute_network.vpc](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network) | resource |
| [google_compute_network_endpoint.ep](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network_endpoint) | resource |
| [google_compute_network_endpoint_group.neg](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network_endpoint_group) | resource |
| [google_compute_region_backend_service.bs](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_backend_service) | resource |
| [google_compute_region_health_check.hc](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_health_check) | resource |
| [google_compute_region_security_policy.armor](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_security_policy) | resource |
| [google_compute_region_security_policy_rule.allowlist](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_security_policy_rule) | resource |
| [google_compute_region_security_policy_rule.default_deny](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_security_policy_rule) | resource |
| [google_compute_region_target_http_proxy.proxy](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_target_http_proxy) | resource |
| [google_compute_region_url_map.urlmap](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_url_map) | resource |
| [google_compute_router.router](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router) | resource |
| [google_compute_router_nat.nat](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router_nat) | resource |
| [google_compute_subnetwork.proxy_only](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork) | resource |
| [google_compute_subnetwork.workload](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork) | resource |
| [google_project_service.required](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| allowed\_src\_ips | Source IP CIDRs allowed by Cloud Armor (e.g. your public IP /32). All other clients get HTTP 403. | `list(string)` | n/a | yes |
| project\_id | Google Cloud Project ID. | `string` | n/a | yes |
| create\_deny\_client | If true, create a VM with an ephemeral external IP that is not allowlisted (expect 403 from that VM). | `bool` | `false` | no |
| machine\_type | Backend VM machine type. | `string` | `"e2-micro"` | no |
| network\_name | VPC network name. | `string` | `"tf-adv-elb09-vpc"` | no |
| proxy\_subnet\_cidr | Proxy-only subnet CIDR. | `string` | `"10.130.0.0/23"` | no |
| proxy\_subnet\_name | Proxy-only subnet name. | `string` | `"tf-adv-elb09-proxy"` | no |
| region | Region for the regional external Application Load Balancer. | `string` | `"asia-northeast1"` | no |
| subnet\_cidr | Workload subnet CIDR. | `string` | `"10.81.0.0/24"` | no |
| subnet\_name | Workload subnet name. | `string` | `"tf-adv-elb09-subnet"` | no |
| zone | Zone for the backend VM. | `string` | `"asia-northeast1-a"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| curl\_allowlisted | From an allowlisted public IP, expect HTTP 200 and backend-a. |
| deny\_client\_ssh | IAP SSH to the optional deny-client VM (expect 403 when curling the VIP from that VM). |
| vip | Regional external Application Load Balancer VIP (port 80). |