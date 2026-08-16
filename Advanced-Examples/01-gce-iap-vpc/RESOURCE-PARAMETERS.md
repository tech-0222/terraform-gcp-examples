# 01 - リソースパラメータ対応

このファイルは **IAP SSH + OS Login + 専用 SA の Spot VM** について、明示設定と公式既定を対応づけます。自動生成の `PARAMETER.md` とは別物です。GCE 項目の読み方は Basic 04 の `INSTANCE-PARAMETERS.md` と同じです。

一次情報（2026-08-16 照合）:

- [google_compute_instance](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance)
- [IAP TCP forwarding](https://cloud.google.com/iap/docs/using-tcp-forwarding)
- [Set up OS Login](https://cloud.google.com/compute/docs/oslogin/set-up-oslogin)
- [google_iap_tunnel_instance_iam](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/iap_tunnel_instance_iam)

## 確認コマンド

```bash
gcloud compute instances describe tf-adv-gce-iap-01 --zone=asia-northeast1-a --format=json
```

## Basic 04 との差分（要点）

| 項目 | Basic 04 | 本サンプル |
|---|---|---|
| ランタイム SA | デフォルト Compute SA（スコープは GCP 既定） | 専用 SA + `scopes = ["cloud-platform"]` |
| IAP / OS Login IAM | コードに含めない | Project の `iap.tunnelResourceAccessor` と `compute.osLogin` |
| Instance IAP IAM | なし | `google_iap_tunnel_instance_iam_member` |
| Firewall | tag `iap-ssh` | 同様。`35.235.240.0/20` → tcp/22 |

## ネットワーク

| 項目 | 本サンプル | Terraform |
|---|---|---|
| VPC | カスタム / `REGIONAL` | `auto_create_subnetworks = false`（未指定なら auto モード既定 true） |
| Subnet | `10.30.0.0/24`、PGA オン | `private_ip_google_access = true` |
| 外部 IP | なし | `access_config` 省略 |

## VM（Spot）

| 項目 | 本サンプル | Terraform / 公式 |
|---|---|---|
| マシン | `e2-medium` | `machine_type`。`allow_stopping_for_update = true` なら停止更新可 |
| ディスク | 20 GB / `pd-balanced` / Debian 12 | `boot_disk.initialize_params` |
| Spot | オン | `provisioning_model = "SPOT"`、`preemptible = true`、`automatic_restart = false`。preemptible のホストメンテナンスは **TERMINATE のみ** |
| OS Login | オン | `metadata.enable-oslogin = "TRUE"` |
| SA スコープ | `cloud-platform` | 専用 SA では IAM ロールで権限を絞り、スコープは広く取るのが [推奨](https://cloud.google.com/compute/docs/access/service-accounts) |

Cloud NAT は作りません。インターネット向け通信は制限されます。
