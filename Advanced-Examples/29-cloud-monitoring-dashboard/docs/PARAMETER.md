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
| [google_cloud_run_v2_service.api](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloud_run_v2_service) | resource |
| [google_cloud_run_v2_service_iam_member.public](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloud_run_v2_service_iam_member) | resource |
| [google_compute_instance.web](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance) | resource |
| [google_compute_network.vpc](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network) | resource |
| [google_compute_router.router](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router) | resource |
| [google_compute_router_nat.nat](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router_nat) | resource |
| [google_compute_subnetwork.main](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork) | resource |
| [google_container_cluster.primary](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_cluster) | resource |
| [google_container_node_pool.primary](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_node_pool) | resource |
| [google_monitoring_alert_policy.run_5xx](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/monitoring_alert_policy) | resource |
| [google_monitoring_dashboard.web](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/monitoring_dashboard) | resource |
| [google_project_iam_member.node](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_service.required](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_service_account.node](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| authorized\_ipv4\_cidr | GKE コントロールプレーンに接続できる CIDR。実行元のグローバル IP を /32 で指定する | `string` | n/a | yes |
| project\_id | 検証に使う Google Cloud プロジェクト ID | `string` | n/a | yes |
| cluster\_name | n/a | `string` | `"tf-adv-dash"` | no |
| environment | VM・GKE・Cloud Run に付ける environment ラベルの値。ダッシュボードの絞り込みに使う | `string` | `"test"` | no |
| network\_name | n/a | `string` | `"tf-adv-dash-vpc"` | no |
| node\_machine\_type | n/a | `string` | `"e2-medium"` | no |
| pods\_cidr | n/a | `string` | `"10.29.16.0/20"` | no |
| region | n/a | `string` | `"asia-northeast1"` | no |
| run\_image | 任意のステータスコードを返せる HTTP サーバ。/status/500 で 500 を返す | `string` | `"docker.io/mccutchen/go-httpbin:2.25.0"` | no |
| run\_service\_name | n/a | `string` | `"tf-adv-dash-api"` | no |
| services\_cidr | n/a | `string` | `"10.29.32.0/20"` | no |
| subnet\_cidr | n/a | `string` | `"10.29.0.0/24"` | no |
| vm\_machine\_type | n/a | `string` | `"e2-small"` | no |
| vm\_name | n/a | `string` | `"tf-adv-dash-vm"` | no |
| zone | n/a | `string` | `"asia-northeast1-a"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| dashboard\_id | Terraform で作ったダッシュボードのリソース名 |
| get\_credentials | kubectl の接続設定 |
| run\_url | n/a |