# 08 - リソースパラメータ対応

このファイルは **本サンプルの Private Cloud DNS** について対応づけます。自動生成の `docs/PARAMETER.md` とは別物です。

一次情報:

- [google_dns_managed_zone](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dns_managed_zone)
- [google_dns_record_set](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dns_record_set)
- [ManagedZones](https://cloud.google.com/dns/docs/reference/v1/managedZones)
- [Private zones](https://cloud.google.com/dns/docs/zones/zones-overview#private-zones)
- [google_compute_instance](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance)
- [IAP TCP forwarding](https://cloud.google.com/iap/docs/using-tcp-forwarding)

## 確認コマンド

```bash
gcloud dns managed-zones describe tf-example-private-zone --format=json
gcloud dns record-sets list --zone=tf-example-private-zone --format=json
gcloud compute instances describe "$(terraform output -raw vm_in_zone_name)" \
  --zone="$(terraform output -raw zone)" --format=json
```

## VPC（Private Zone の可視範囲）

| 項目 | 本サンプル | Terraform |
|---|---|---|
| 名前 | `tf-example-dns-vpc` | `google_compute_network.dns` |
| 自動サブネット | オフ | `auto_create_subnetworks = false` |
| routing_mode | 未指定 | API / Provider が `REGIONAL` を返すことが多い。明示はしていない |
| Subnet | `tf-example-dns-subnet` / `10.30.0.0/24` | `google_compute_subnetwork.dns` |
| Firewall | IAP SSHのみ。tag `iap-ssh` | `source_ranges = ["35.235.240.0/20"]`、`target_tags = ["iap-ssh"]` |

## 別VPC（Private Zoneの可視範囲に含まれない）

名前解決が拒否されることを確認するための、Zoneに紐づかない別VPCです。構成はPrivate Zone用VPCと同じ（Subnet 1つ、IAP SSH Firewallのみ）で、Zoneへ紐づけていない点だけが違います。

| 項目 | 本サンプル | Terraform |
|---|---|---|
| 名前 | `tf-example-dns-external-vpc` | `google_compute_network.external` |
| Subnet | `tf-example-dns-external-subnet` / `10.31.0.0/24` | `google_compute_subnetwork.external` |
| Firewall | IAP SSHのみ。tag `iap-ssh` | `google_compute_firewall.allow_iap_ssh_external` |

## 検証用VM（google_compute_instance）

Private ZoneのVPCに紐づいたVMと、紐づかない別VPCのVMを1台ずつ作成し、名前解決の可否を実際に確認します。設定は`04-compute-engine`のVM（Spot / 外部IPなし / OS Login）と同じです。

| 項目 | 本サンプル | Terraform | 備考 |
|---|---|---|---|
| `vm_in_zone` | `tf-example-dns-vm-in-zone` | `google_compute_instance.vm_in_zone` | `tf-example-dns-subnet`（Zoneに紐づくVPC）に配置 |
| `vm_outside_zone` | `tf-example-dns-vm-outside-zone` | `google_compute_instance.vm_outside_zone` | `tf-example-dns-external-subnet`（Zoneに紐づかないVPC）に配置 |
| Machine type | `e2-medium` | `machine_type` | |
| 外部IP | なし | `network_interface`に`access_config`を置かない | IAP経由でのみSSH |
| Provisioning | Spot | `scheduling.provisioning_model = "SPOT"` | 回収される可能性あり |
| OS Login | 有効 | `metadata.enable-oslogin = "TRUE"` | |

手元の端末（インターネット経由）からの確認にはVMを使わず、ローカルの`getent hosts`で直接試します。

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
