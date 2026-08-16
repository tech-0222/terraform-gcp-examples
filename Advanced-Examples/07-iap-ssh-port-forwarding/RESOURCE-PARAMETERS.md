# 07 - リソースパラメータ対応

このファイルは **IAP SSH + Local Port Forwarding + 非公開 nginx** について対応づけます。自動生成の `PARAMETER.md` とは別物です。Advanced 01 との差分は NAT・startup・スコープ・HTTP 非公開です。

一次情報（2026-08-16 照合）:

- [IAP TCP forwarding](https://cloud.google.com/iap/docs/using-tcp-forwarding)
- [Cloud NAT](https://cloud.google.com/nat/docs/overview)
- [google_compute_router_nat](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router_nat)
- [google_compute_instance](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance)

## 確認コマンド

```bash
gcloud compute instances describe tf-adv-iap-forward-vm --zone=asia-northeast1-a --format=json
gcloud compute routers nats describe tf-adv-iap-forward-vpc-nat \
  --router=tf-adv-iap-forward-vpc-router --region=asia-northeast1 --format=json
```

## ネットワーク

| 項目 | 本サンプル | Terraform / 公式 |
|---|---|---|
| VPC / Subnet | カスタム、`10.70.0.0/24`、PGA オン | 01 と同型 |
| Cloud Router | リージョン | NAT の前提 |
| Cloud NAT | `AUTO_ONLY` | エフェメラル NAT IP を自動割り当て |
| NAT 対象 | この Subnet の `ALL_IP_RANGES` | `source_subnetwork_ip_ranges_to_nat = LIST_OF_SUBNETWORKS`。VPC 全体 NAT ではない |
| Firewall | IAP `35.235.240.0/20` → tcp/22、tag `iap-ssh` | **tcp/80 は許可しない**。HTTP は SSH トンネル内のみ |

NAT はアウトバウンド（apt で nginx 導入）用です。IAP のインバウンド経路ではありません。

## VM

| 項目 | 本サンプル | Terraform / 公式 |
|---|---|---|
| マシン | `e2-small` | 01 の e2-medium より小さい |
| 外部 IP | なし | `access_config` 省略 |
| Spot | オン | preemptible のメンテナンスは TERMINATE のみ |
| OS Login | オン | |
| startup-script | `startup.sh`（nginx） | `metadata.startup-script` |
| SA スコープ | `logging.write` のみ | 01 の `cloud-platform` より狭い。パッケージ取得は NAT 経由で GCP スコープ不要 |
| IAP / OS Login IAM | 01 と同様 | Project + instance の tunnel IAM |

Local bind は `127.0.0.1` を明示し、IPv6 loopback が使えない環境での bind 失敗を避けます（README / outputs）。
