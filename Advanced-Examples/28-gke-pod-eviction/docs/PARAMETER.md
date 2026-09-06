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
| [google_compute_network.vpc](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network) | resource |
| [google_compute_router.router](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router) | resource |
| [google_compute_router_nat.nat](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router_nat) | resource |
| [google_compute_subnetwork.gke](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork) | resource |
| [google_container_cluster.primary](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_cluster) | resource |
| [google_container_node_pool.primary](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_node_pool) | resource |
| [google_project_iam_member.node](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_service.required](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_service_account.node](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| authorized\_ipv4\_cidr | コントロールプレーンに接続できる CIDR。実行元のグローバル IP を /32 で指定する。<br/><br/>ノードは外部 IP を持たない（enable\_private\_nodes = true）が、<br/>コントロールプレーンは公開エンドポイントにしている。踏み台を立てずに<br/>kubectl を使うため。退避の観測が主題で、ネットワーク構成は主題ではない。 | `string` | n/a | yes |
| project\_id | 検証に使う Google Cloud プロジェクト ID | `string` | n/a | yes |
| cluster\_name | n/a | `string` | `"tf-adv-evict"` | no |
| network\_name | n/a | `string` | `"tf-adv-evict-vpc"` | no |
| node\_count | n/a | `number` | `1` | no |
| node\_machine\_type | ノードのマシンタイプ。<br/><br/>退避を起こすには、Pod が確保できるメモリがノードの容量に近い必要がある。<br/>大きすぎると、退避させるために大量のメモリを掴む Pod が要る。<br/>e2-medium（4GB）だと allocatable が 2.8GB しかなく、GMP の収集コンポーネントを<br/>載せると退避を起こす余地が残らない。e2-standard-2（8GB）にする。 | `string` | `"e2-standard-2"` | no |
| pods\_cidr | n/a | `string` | `"10.28.16.0/20"` | no |
| region | n/a | `string` | `"asia-northeast1"` | no |
| services\_cidr | n/a | `string` | `"10.28.32.0/20"` | no |
| subnet\_cidr | n/a | `string` | `"10.28.0.0/24"` | no |
| use\_spot | Spot VM を使う。検証用途では費用を抑えられる | `bool` | `true` | no |
| zone | ゾーンクラスタにする。退避の観測にノードは1台で足りる | `string` | `"asia-northeast1-a"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| cluster\_name | n/a |
| get\_credentials | kubectl の接続設定 |
| node\_machine\_type | n/a |