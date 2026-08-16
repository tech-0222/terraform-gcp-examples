# 08 - リソースパラメータ対応

このファイルは **Regional External ALB + zonal NEG** の明示設定と公式既定を対応づけます。自動生成の `PARAMETER.md` とは別物です。09 / 10 の共通ネットワーク項目の正本はここです。

一次情報（2026-08-16 照合）:

- [Proxy-only subnets](https://cloud.google.com/load-balancing/docs/proxy-only-subnets)
- [Regional external Application Load Balancer](https://cloud.google.com/load-balancing/docs/https)
- [Zonal NEG (GCE_VM_IP_PORT)](https://cloud.google.com/load-balancing/docs/negs/zonal-neg-concepts)
- [google_compute_region_backend_service](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_backend_service)
- [google_compute_forwarding_rule](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_forwarding_rule)

## 確認コマンド

```bash
gcloud compute forwarding-rules list --filter="region:asia-northeast1"
gcloud compute backend-services list --regions=asia-northeast1
gcloud compute network-endpoint-groups list
```

## ネットワーク

| 項目 | 本サンプル | Terraform / 公式 |
|---|---|---|
| VPC | カスタム / `REGIONAL` | `auto_create_subnetworks = false` |
| ワークロード Subnet | `10.80.0.0/24`、PGA オン | `private_ip_google_access = true` |
| proxy-only Subnet | `10.128.0.0/23` | `purpose = REGIONAL_MANAGED_PROXY`、`role = ACTIVE`。Envoy 用。省略すると regional ALB は作れない |
| NAT | `AUTO_ONLY`、この Subnet のみ | アウトバウンド専用 |
| FW（HC） | `130.211.0.0/22`、`35.191.0.0/16` → tcp/8080 | Google ヘルスチェックレンジ |
| FW（proxy） | proxy-only CIDR → tcp/8080 | tag `lb-backend` |
| FW（IAP） | `35.235.240.0/20` → tcp/22 | tag `iap-ssh`。HTTP は公開しない |

## ロードバランサ

| 項目 | 本サンプル | Terraform / 公式 |
|---|---|---|
| 種別 | Regional External Application LB | `load_balancing_scheme = EXTERNAL_MANAGED` |
| ネットワークティア | PREMIUM | `network_tier` |
| VIP | リージョン外部 IP | `google_compute_address` + forwarding rule。`network = vpc.id` が同一 VPC 判定に必要 |
| :81 | URL map → bs-a | Forwarding Rule `port_range = "81"` |
| :82 | URL map → bs-b | `port_range = "82"` |
| Backend | RATE / 100 per endpoint | NEG バックエンドでは RATE が一般的 |
| セッション | 未指定 | 既定は NONE。Cookie 固定は 10 |
| Cloud Armor | なし | 09 で付与 |

## NEG / VM

| 項目 | 本サンプル | Terraform / 公式 |
|---|---|---|
| NEG 種別 | `GCE_VM_IP_PORT` | ゾーンは VM と同じ |
| ポート | 8080 | `default_port` / endpoint `port` |
| VM 外部 IP | なし | `access_config` 省略 |
| マシン | `e2-micro` | 静的 HTML 用。ヘルスチェックのため非 Spot |

検証後は必ず destroy してください。
