# 09 - リソースパラメータ対応

08 と同型の Regional External ALB に **リージョナル Cloud Armor** を足した差分です。VPC / proxy-only / NEG の説明は [08 の RESOURCE-PARAMETERS.md](../08-regional-external-alb-neg/RESOURCE-PARAMETERS.md) を正本とします。

一次情報:

- [Cloud Armor](https://cloud.google.com/armor/docs)
- [google_compute_region_security_policy](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_security_policy)
- [google_compute_region_backend_service](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_backend_service)

## Cloud Armor

| 項目 | 本サンプル | Terraform / 公式 |
|---|---|---|
| スコープ | リージョン | Regional ALB には regional policy |
| 許可 | priority 1000 / `allow` / `SRC_IPS_V1` | `allowed_src_ips` |
| 既定 | priority 2147483647 / `deny(403)` / `*` | |
| 紐付け | Backend Service | `security_policy`。**VIP 宛**で評価。`:8080` 直アクセスでは効かない |
| ヘルスチェック | Armor 対象外 | FW の HC レンジで通す |

CIDR は 08 と衝突しないよう `10.81.0.0/24` / proxy `10.130.0.0/23` です。Forwarding Rule は **tcp/80** のみです。
