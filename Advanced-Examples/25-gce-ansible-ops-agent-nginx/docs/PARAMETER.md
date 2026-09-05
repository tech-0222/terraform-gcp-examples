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
| google | 7.46.1 |

## Resources

| Name | Type |
| ---- | ---- |
| [google_compute_address.nat_egress](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_address) | resource |
| [google_compute_firewall.allow_iap_http](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.allow_iap_ssh](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_instance.web](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance) | resource |
| [google_compute_network.vpc](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network) | resource |
| [google_compute_router.nat](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router) | resource |
| [google_compute_router_nat.nat](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router_nat) | resource |
| [google_compute_subnetwork.main](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork) | resource |
| [google_project_iam_member.compute_viewer](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.iap_tunnel](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.os_login](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.vm](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_service.required](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_service_account.vm](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [google_storage_bucket.ansible](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket) | resource |
| [google_storage_bucket_iam_member.vm_read](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_iam_member) | resource |
| [google_storage_bucket_object.ansible](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_object) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| iap\_member | IAM member granted IAP tunnel access (e.g. user:you@example.com). Must match your ADC / gcloud user for verification. | `string` | n/a | yes |
| project\_id | Google Cloud Project ID. | `string` | n/a | yes |
| bucket\_prefix | Prefix for the Ansible asset bucket. The project ID is appended because bucket names are globally unique. | `string` | `"tf-adv-gce-ansible"` | no |
| instance\_name | VM name. | `string` | `"tf-adv-gce-ans-web"` | no |
| machine\_type | Machine type. e2-small is enough for nginx plus the Ops Agent; e2-micro runs out of memory during the agent install. | `string` | `"e2-small"` | no |
| network\_name | VPC network name. | `string` | `"tf-adv-gce-ans-vpc"` | no |
| region | Region for the subnet and the GCS bucket. | `string` | `"asia-northeast1"` | no |
| subnet\_cidr | CIDR of the subnet. | `string` | `"10.50.0.0/24"` | no |
| subnet\_name | Subnet name. | `string` | `"tf-adv-gce-ans-subnet"` | no |
| use\_spot | Use a Spot VM to reduce cost. Spot instances can be reclaimed, which also makes the first-boot-only behaviour of the startup script easy to observe. | `bool` | `true` | no |
| zone | Zone for the VM. | `string` | `"asia-northeast1-a"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| bucket\_name | Bucket holding the Ansible assets. |
| curl\_via\_iap\_tunnel\_example | Forward port 80 over IAP, then curl nginx from outside the VPC. The VM has no external IP. |
| instance\_name | VM name. |
| internal\_ip | The VM's internal IP. There is no external one. |
| project\_id | Google Cloud Project ID. |
| rerun\_playbook\_example | Re-run Ansible on the existing VM. This is what a playbook edit needs, because the startup script will not run again. |
| ssh\_example | Reach the VM over IAP. |
| startup\_log\_example | The startup script's own log. Its line count is how first-boot-only behaviour is checked. |
| zone | Zone of the VM. |