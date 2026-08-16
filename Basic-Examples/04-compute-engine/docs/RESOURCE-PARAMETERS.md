# 04 - リソースパラメータ対応

VM（`google_compute_instance`）のコンソール項目対応は **[INSTANCE-PARAMETERS.md](./INSTANCE-PARAMETERS.md)** を正本とします。このファイルは準備ネットワークと API 有効化をまとめます。

一次情報:

- [google_compute_network](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network)
- [google_compute_subnetwork](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork)
- [google_compute_firewall](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall)
- [IAP TCP forwarding](https://cloud.google.com/iap/docs/using-tcp-forwarding)

## 確認コマンド

```bash
gcloud compute networks describe tf-example-gce-vpc --format=json
gcloud compute instances describe "$(terraform output -raw instance_name)" \
  --zone="$(terraform output -raw zone)" --format=json
```

## google_project_service.compute

| 項目 | 本サンプル | Terraform |
|---|---|---|
| サービス | `compute.googleapis.com` | `service` |
| destroy 時に無効化 | `false` | `disable_on_destroy` |

## ネットワーク

| 項目 | 本サンプル | Terraform | 備考 |
|---|---|---|---|
| VPC | `tf-example-gce-vpc`、カスタムモード、`REGIONAL` | `auto_create_subnetworks = false`、`routing_mode = "REGIONAL"` | 未指定の auto モード既定は `true` |
| Subnet | `tf-example-gce-subnet` / `10.20.0.0/24` / PGA オン | `private_ip_google_access = true` | Cloud NAT なし |
| Firewall | IAP SSH のみ。tag `iap-ssh` | `source_ranges = ["35.235.240.0/20"]`、`target_tags = ["iap-ssh"]` | 02 と違い **target_tags あり**。HTTP/HTTPS は作らない |

VM の Spot / 外部 IP なし / OS Login / ディスクは `INSTANCE-PARAMETERS.md` を参照してください。
