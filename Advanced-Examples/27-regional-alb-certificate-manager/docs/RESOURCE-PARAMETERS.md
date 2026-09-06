# リソースのパラメータ対応

コンソール / API の項目と、Terraform の属性の対応。

## Certificate Manager: DNS 認証

| コンソール / gcloud | Terraform | 備考 |
|---|---|---|
| DNS authorization > Location | `google_certificate_manager_dns_authorization.location` | 既定は `global`。**リージョン証明書には同じリージョンの認証が要る** |
| Type | `type` | 既定は location 依存。**リージョンでは `PER_PROJECT_RECORD` のみ** |
| CNAME record name | `dns_resource_record[0].name`（出力） | global は `_acme-challenge.<domain>`、リージョンは `_acme-challenge_<接尾辞>.<domain>` |
| CNAME record value | `dns_resource_record[0].data`（出力） | |

`--type=FIXED_RECORD` をリージョンで指定すると `FIXED_RECORD type is not supported in this environment` で弾かれる。

## Certificate Manager: 証明書

| コンソール / gcloud | Terraform | 備考 |
|---|---|---|
| Certificate > Location | `location` | リージョン証明書はリージョン ALB 用 |
| Domains | `managed.domains` | |
| DNS authorizations | `managed.dns_authorizations` | **これを指定すると DNS 認証。省略すると LB 認証** |
| Issuance config | `managed.issuance_config` | private PKI 用。`dns_authorizations` とは排他 |
| Scope | `scope` | `DEFAULT` / `EDGE_CACHE` / `ALL_REGIONS` / `CLIENT_AUTH` |
| Status | `managed.state`（出力） | `PROVISIONING` / `ACTIVE` / `FAILED` |
| Authorization attempt | `managed.authorization_attempt_info`（出力） | `state` / `failure_reason` / `details`。**止まった理由はここでしか読めない** |

`dns_authorizations` を書くかどうかだけで認証方式が変わる。コンソールの「認証タイプ」に対応する専用の属性は無い。

## ロードバランサへのアタッチ

| | リージョン | グローバル |
|---|---|---|
| リソース | `google_compute_region_target_https_proxy` | `google_compute_target_https_proxy` |
| Certificate Manager の証明書 | `certificate_manager_certificates`（**直接**） | `certificate_map`（**マップ経由**） |
| Compute Engine の証明書 | `ssl_certificates` | `ssl_certificates` |
| 併用 | **不可**（`sslCertificates and certificateManagerCertificates can't be defined together`） | — |

`certificate_map` に渡す値は `//certificatemanager.googleapis.com/` から始まる完全形が要る。

```hcl
certificate_map = "//certificatemanager.googleapis.com/${google_certificate_manager_certificate_map.global[0].id}"
```

## リージョン外部 ALB

| コンソール | Terraform | 備考 |
|---|---|---|
| Load balancer type | `load_balancing_scheme = "EXTERNAL_MANAGED"` | 転送ルールとバックエンドサービスの両方に要る |
| Proxy-only subnet | `google_compute_subnetwork.purpose = "REGIONAL_MANAGED_PROXY"` | リージョン ALB に必須。グローバルには不要 |
| Backend > Capacity | `backend.capacity_scaler` | **省略すると `managed backend service must have at least one non-zero capacity_scaler` で plan が落ちる** |
| Backend > Balancing mode | `backend.balancing_mode` | NEG では `RATE` |
| Network tier | `network_tier` | 転送ルールと外部 IP で揃える |

## Cloud DNS

| コンソール | Terraform | 備考 |
|---|---|---|
| Zone > DNS name | `dns_name` | **末尾のドットが要る** |
| Name servers | `name_servers`（出力） | 親ドメインの NS に設定する。**ゾーンを作っただけでは権威にならない** |
