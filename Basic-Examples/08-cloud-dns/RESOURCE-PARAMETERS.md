# 08 - リソースパラメータ対応

このファイルは **本サンプルの Private Cloud DNS** について対応づけます。自動生成の `PARAMETER.md` とは別物です。

一次情報（2026-08-16 照合）:

- [google_dns_managed_zone](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dns_managed_zone)
- [google_dns_record_set](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dns_record_set)
- [ManagedZones](https://cloud.google.com/dns/docs/reference/v1/managedZones)
- [Private zones](https://cloud.google.com/dns/docs/zones/zones-overview#private-zones)

## 確認コマンド

```bash
gcloud dns managed-zones describe tf-example-private-zone --format=json
gcloud dns record-sets list --zone=tf-example-private-zone --format=json
```

## VPC（Private Zone の可視範囲）

| 項目 | 本サンプル | Terraform |
|---|---|---|
| 名前 | `tf-example-dns-vpc` | `google_compute_network.dns` |
| 自動サブネット | オフ | `auto_create_subnetworks = false` |
| routing_mode | 未指定 | API / Provider が `REGIONAL` を返すことが多い。明示はしていない |

Subnet は作りません。Zone の可視性に VPC が必要なだけです。

## google_dns_managed_zone.private

| 項目 | 本サンプル | 区分 | Terraform | gcloud パス |
|---|---|---|---|---|
| ゾーン名 | `tf-example-private-zone` | 明示 | `name`（リソース ID） | `name` |
| DNS 名 | `example.internal.` | 明示 | `dns_name`。**末尾ドット必須** | `dnsName` |
| 可視性 | private | 明示 | `visibility = "private"`。未指定は public | `visibility` |
| 公開する VPC | 上記 VPC | 明示 | `private_visibility_config.networks.network_url` | `privateVisibilityConfig.networks` |

Public Zone / DNSSEC は使いません。

## google_dns_record_set.example

| 項目 | 本サンプル | Terraform | API |
|---|---|---|---|
| FQDN | `app.example.internal.` | `name` | `name` |
| タイプ | A | `type` | `type` |
| TTL | `300` | `ttl` | `ttl` |
| データ | `10.10.0.10` | `rrdatas` | `rrdatas` |

この A レコードは実在 VM を指しません。名前解決の確認用です。
