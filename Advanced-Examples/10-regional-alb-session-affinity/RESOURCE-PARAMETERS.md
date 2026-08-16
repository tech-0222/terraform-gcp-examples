# 10 - リソースパラメータ対応

08 と同型の Regional External ALB に **セッションアフィニティ** を足した差分です。VPC / proxy-only / NEG は [08 の RESOURCE-PARAMETERS.md](../08-regional-external-alb-neg/RESOURCE-PARAMETERS.md) を正本とします。

一次情報（2026-08-16 照合）:

- [Request distribution](https://cloud.google.com/load-balancing/docs/https/request-distribution)
- [google_compute_region_backend_service](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_backend_service)

## セッション

| 項目 | 本サンプル | Terraform / 公式 |
|---|---|---|
| :81 | `GENERATED_COOKIE` | LB が Cookie を発行。TTL `affinity_cookie_ttl_sec`（既定 3600） |
| :83 | `HTTP_COOKIE` | `consistent_hash.http_cookie.name = ROUTE`、`path = /`。`locality_lb_policy = RING_HASH` |
| 未指定時 | NONE | 08 は未指定 |

CIDR は `10.82.0.0/24` / proxy `10.132.0.0/23` です。バックエンドは同一ゾーン 2 台のみです。
