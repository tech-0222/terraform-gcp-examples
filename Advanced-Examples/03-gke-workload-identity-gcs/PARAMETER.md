# Parameters（自動生成）

このファイルは [terraform-docs](https://github.com/terraform-docs/terraform-docs) により自動生成されます。手動で編集しないでください。

## Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.10.0, < 2.0.0 |
| google | ~> 7.0 |
| kubernetes | ~> 2.35 |

## Providers

| Name | Version |
| ---- | ------- |
| google | 7.43.0 |
| kubernetes | 2.38.0 |

## Resources

| Name | Type |
| ---- | ---- |
| [google_compute_network.vpc](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network) | resource |
| [google_compute_subnetwork.primary](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork) | resource |
| [google_container_cluster.primary](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_cluster) | resource |
| [google_container_node_pool.spot](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_node_pool) | resource |
| [google_project_service.required](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_service_account.gcs](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [google_service_account_iam_member.workload_identity_user](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account_iam_member) | resource |
| [google_storage_bucket.demo](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket) | resource |
| [google_storage_bucket_iam_member.gcs_writer](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_iam_member) | resource |
| [kubernetes_job_v1.gcs_write](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/job_v1) | resource |
| [kubernetes_namespace_v1.demo](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace_v1) | resource |
| [kubernetes_service_account_v1.gcs](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service_account_v1) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| project\_id | Google Cloud Project ID. | `string` | n/a | yes |
| bucket\_name\_prefix | Prefix for the GCS bucket (suffix is project\_id). | `string` | `"tf-adv-gke-wi"` | no |
| cluster\_name | GKE cluster name. | `string` | `"tf-adv-gke-wi"` | no |
| k8s\_namespace | Kubernetes namespace for the Workload Identity demo. | `string` | `"wi-demo"` | no |
| k8s\_service\_account | Kubernetes ServiceAccount name bound to the GCP SA. | `string` | `"gcs-writer"` | no |
| machine\_type | Node machine type. | `string` | `"e2-medium"` | no |
| network\_name | VPC network name. | `string` | `"tf-adv-gke-wi-vpc"` | no |
| node\_count | Number of nodes in the Spot node pool. | `number` | `1` | no |
| object\_name | Object path written by the demo Job. | `string` | `"workload-identity/hello.txt"` | no |
| pods\_cidr | Secondary CIDR for Pods. | `string` | `"10.51.0.0/16"` | no |
| region | Region for the subnet and GCS bucket. | `string` | `"asia-northeast1"` | no |
| services\_cidr | Secondary CIDR for Services. | `string` | `"10.52.0.0/20"` | no |
| subnet\_cidr | Primary subnet CIDR. | `string` | `"10.50.0.0/24"` | no |
| subnet\_name | Subnet name. | `string` | `"tf-adv-gke-wi-subnet"` | no |
| zone | Zone for the zonal GKE cluster. | `string` | `"asia-northeast1-a"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| bucket\_name | GCS bucket used by the Workload Identity demo. |
| cluster\_location | GKE cluster location (zone). |
| cluster\_name | GKE cluster name. |
| gcp\_service\_account\_email | GCP SA impersonated by the Kubernetes SA. |
| get\_credentials\_example | Example command to fetch kubeconfig. |
| gsutil\_cat\_example | Read the object written by the Job. |
| k8s\_namespace | Kubernetes namespace for the demo. |
| k8s\_service\_account | Kubernetes ServiceAccount bound via Workload Identity. |
| object\_name | Object written by the demo Job. |