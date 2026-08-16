# 02 - リソースパラメータ対応

このファイルは本サンプルの VPC / Subnet / Firewall について、GCP / `gcloud --format=json` / Terraform 属性を対応づけます。自動生成の `PARAMETER.md` とは別物です。

一次情報:

- [google_compute_network](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network)
- [google_compute_subnetwork](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork)
- [google_compute_firewall](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall)
- [VPC networks](https://cloud.google.com/vpc/docs/vpc)
- [IAP TCP forwarding](https://cloud.google.com/iap/docs/using-tcp-forwarding)
- [google_project_service](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_project_service)

## 凡例

| 記号 | 意味 |
|---|---|
| **明示** | コード / 変数で指定 |
| **未指定** | Provider / GCP のデフォルト |
| **再作成 ○** | 変更で replace になりやすい |

## 確認コマンド

```bash
gcloud compute networks describe tf-example-vpc --format=json
gcloud compute networks subnets describe tf-example-subnet --region=asia-northeast1 --format=json
gcloud compute firewall-rules list --filter="network:tf-example-vpc" --format=json
```

## google_project_service.compute

| 項目 | 本サンプル | Terraform |
|---|---|---|
| サービス | `compute.googleapis.com` | `service` |
| destroy 時に無効化 | `false` | `disable_on_destroy`（未設定でも destroy 後は有効のまま） |

## google_compute_network.vpc

| 項目 | 本サンプル | 区分 | 再作成 | Terraform | gcloud パス |
|---|---|---|---|---|---|
| 名前 | `tf-example-vpc` | 明示 | ○ | `name` | `name` |
| 自動サブネット | オフ（カスタムモード） | 明示 | ○ | `auto_create_subnetworks = false`。未指定時の Provider 既定は `true`（auto モード、各リージョンに `10.128.0.0/9` から Subnet） | `autoCreateSubnetworks` |
| ルーティング | `REGIONAL` | 明示 | − | `routing_mode`。`REGIONAL` / `GLOBAL` | `routingConfig.routingMode` |
| MTU | 未指定 | 未指定 | − | `mtu`。未指定時 1460 bytes | `mtu` |
| デフォルト経路削除 | しない | 未指定 | − | `delete_default_routes_on_create` 既定 `false` | — |

## google_compute_subnetwork.primary

| 項目 | 本サンプル | 区分 | Terraform | gcloud パス |
|---|---|---|---|---|
| 名前 | `tf-example-subnet` | 明示 | `name` | `name` |
| リージョン | `asia-northeast1` | 明示 | `region` | `region` |
| プライマリ CIDR | `10.10.0.0/24` | 明示 | `ip_cidr_range` | `ipCidrRange` |
| Private Google Access | オン | 明示 | `private_ip_google_access = true`。未指定時はオフ | `privateIpGoogleAccess` |
| セカンダリ範囲 | なし | 未指定 | `secondary_ip_range` | `secondaryIpRanges` |

カスタムモード VPC では Subnet の指定が必須です（[Network API](https://cloud.google.com/compute/docs/reference/rest/v1/networks)）。

## google_compute_firewall

優先度はどちらも `1000`（Firewall の一般的な既定）。`target_tags` は付けていません。タグもサービスアカウントも無いルールは、その VPC の全インスタンスに適用されます（[VPC firewall rules](https://cloud.google.com/vpc/docs/firewalls)）。

| ルール | 許可 | 送信元 | Terraform |
|---|---|---|---|
| `tf-example-vpc-allow-internal` | tcp / udp / icmp（ポート指定なし = 全ポート） | `10.10.0.0/24` | `allow` + `source_ranges` |
| `tf-example-vpc-allow-iap-ssh` | tcp/22 | `35.235.240.0/20`（IAP TCP forwarding） | 同上 |

HTTP/HTTPS 用ルールは作りません。
