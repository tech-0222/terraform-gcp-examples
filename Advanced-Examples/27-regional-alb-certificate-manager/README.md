# 27. Certificate Manager の DNS 認証と LB 認証を比べる（リージョン ALB）

Certificate Manager の **DNS 認証** と **LB 認証** を並べて実測する。

リージョン外部 Application Load Balancer では、Compute Engine のマネージド SSL 証明書が使えない。

> Compute Engine Google-managed SSL certificates aren't supported for regional external Application Load Balancers, regional internal Application Load Balancers, or cross-region internal Application Load Balancers.

つまりリージョン ALB で **Google-managed 証明書**（Google Cloud が発行・更新を管理するもの）を使うなら、Certificate Manager が唯一の選択肢になる。自己管理の証明書や、[Public CA から ACME で取得した証明書](https://docs.cloud.google.com/certificate-manager/docs/public-ca-tutorial)を持ち込む道は別にある。

## 何を検証するか

| # | 検証すること |
|---|---|
| 1 | 証明書が ACTIVE になるまでの実測時間 |
| 2 | **ロードバランサが無くても DNS 認証で発行できるか** |
| 3 | global の DNS 認証をリージョン証明書に渡すとどうなるか |
| 4 | リージョンで `FIXED_RECORD` を選べるか |
| 5 | `certificate_manager_certificates` で直接アタッチして TLS が張れるか |
| 6 | Compute Engine マネージド証明書をリージョン ALB に付けられるか |
| 7 | Cloud Logging に何が残るか |

## 構成

```
A. DNS 認証 + リージョン証明書 -> リージョン外部 ALB   (regional.<domain>)
B. LB  認証 + グローバル証明書 -> グローバル外部 ALB   (global.<domain>)
C. DNS 認証 + リージョン証明書 -> どこにも繋がない     (nolb.<domain>)
```

バックエンドは VM 1台。ゾーン NEG を A と B で共用する。C は証明書だけで、A レコードも LB も作らない。

## 前提条件

- Terraform、Google Cloud CLI
- Billing が有効な検証用プロジェクト
- **親ドメインから、このサブドメインを Cloud DNS へ委任できること**
- 検証時のバージョン：Terraform 1.14.3、google 7.x

委任しないと DNS 認証の CNAME が公開 DNS で解決できず、認証が完了しない。証明書の状態は [`managed.state`](https://cloud.google.com/certificate-manager/docs/reference/certificate-manager/rest/v1/projects.locations.certificates)（`PROVISIONING` / `FAILED` / `ACTIVE`）、認証試行の状態は `managed.authorizationAttemptInfo[].state` で見る。

## 使い方

```bash
cp terraform.tfvars.example terraform.tfvars   # project_id と dns_zone_domain を埋める
terraform init
terraform apply
terraform output name_servers                  # 親ドメインの NS に設定する
```

**Certificate Manager API を有効化した直後は失敗することがある。**

```
Certificate Manager API has not been used in project ... before or it is disabled.
"reason": "SERVICE_DISABLED"
```

`google_project_service` は Service Usage の有効化オペレーションの完了まで待つが、**それは各 API がすぐ使えることまでは保証しない。** 今回は有効化直後の Certificate Manager 呼び出しが `SERVICE_DISABLED` になり、もう一度 `apply` すると通った。再実行しても失敗するなら、エラーに出ているプロジェクトと API の有効化状態を確かめる。

## 実測結果

### 1. 発行までの時間は、ほぼ DNS の伝播待ち

| | ACTIVE まで |
|---|---|
| 初回（委任した直後） | **38分53秒** |
| 2回目（委任済みのゾーンに追加） | **4分12秒** |

同じプロジェクト、同じゾーン、同じ手順で **9倍以上の差**が出た。違いは委任してからの経過時間だけ。

**計測の起点と取得間隔は記録していない。** 掲載値はこの回の観測でしかない。測り直すなら、所要時間を「証明書の`createTime`から[`managed.state=ACTIVE`](https://docs.cloud.google.com/certificate-manager/docs/reference/certificate-manager/rest/v1/projects.locations.certificates)を初めて確認するまで」と定義し、NS 設定時刻・DNS の解決確認時刻・取得間隔も併せて残す。

**この測定では DNS の伝播と Certificate Manager・CA 側の処理を切り分けていない。** どちらがどれだけ効いたかは言えないので、発行処理単体の所要時間や上限についてはここでは結論を出さない。

### 2. 途中で FAILED になり、そこから復帰する

```
    0秒          regional=AUTHORIZING      global=AUTHORIZING
 29分20秒        regional=FAILED           global=FAILED        ← ここで諦めない
 38分20秒        regional=AUTHORIZED       global=FAILED
 38分53秒        regional=ACTIVE           global=FAILED
 40分35秒        regional=ACTIVE           global=ACTIVE
```

**`FAILED` は終状態ではない。** 29分の時点で見ていたら「失敗した」と判断していた。

### 3. ロードバランサが無くても発行できる

`nolb.<domain>` は A レコードもロードバランサも作らず、DNS 認証の CNAME だけを置いた。

```
      0s  PROVISIONING/AUTHORIZING
    220s  PROVISIONING/AUTHORIZED
    252s  ACTIVE/AUTHORIZED
```

**4分12秒で ACTIVE。** DNS 認証は配信経路と無関係に発行できる。

LB 認証では原理的にできない。[認証の条件](https://docs.cloud.google.com/certificate-manager/docs/domain-authorization#load_balancer_authorization)は、証明書を関連付けたロードバランサの構成が済んでいて、そのホスト名の **A / AAAA が返すすべての IP でポート 443 からその証明書を使えること**だから。AAAA の取り違え、証明書の未関連付け、443 の未開放はいずれも[失敗の原因になる](https://docs.cloud.google.com/certificate-manager/docs/troubleshooting)。**既存サイトを LB に載せ替えるとき、DNS 認証なら配信経路を切り替える前に証明書を用意できる。**

### 4. リージョンでは PER_PROJECT_RECORD しか選べない

| | global | リージョン |
|---|---|---|
| 種別 | `FIXED_RECORD` | `PER_PROJECT_RECORD` |
| CNAME | `_acme-challenge.<domain>` | `_acme-challenge_<接尾辞>.<domain>` |

`--type=FIXED_RECORD` を指定すると弾かれる。

```
description: FIXED_RECORD type is not supported in this environment
subject: FIXED_RECORD
type: DATA_INVALID
```

**CNAME の名前が変わる。** `_acme-challenge` を決め打ちで書いたコードは、リージョンでは動かない。

このコードでは名前を認証リソースの出力から取っている。

```hcl
resource "google_dns_record_set" "acme_challenge_regional" {
  name = google_certificate_manager_dns_authorization.regional.dns_resource_record[0].name
  type = google_certificate_manager_dns_authorization.regional.dns_resource_record[0].type
  rrdatas = [google_certificate_manager_dns_authorization.regional.dns_resource_record[0].data]
  ...
}
```

### 5. location が違う認証を渡すと「存在しない」と言われる

global に作った DNS 認証を、リージョン証明書に渡した結果。

```
ERROR: INVALID_ARGUMENT: dns authorization doesn't exist
- field: managed.dns_authorizations[0]
```

**認証は存在する。** location が違うだけ。

```
projects/.../locations/global/dnsAuthorizations/...            FIXED_RECORD
projects/.../locations/asia-northeast1/dnsAuthorizations/...   PER_PROJECT_RECORD
```

公式の記述と対応している。

> For regional Google-managed certificates, you must create a regional DNS authorization in the same region as the certificate. You can't use global DNS authorizations with regional certificates.

### 6. アタッチ試行でリージョンパスの NOT_FOUND が出る

```
ERROR: Could not fetch resource:
 - The resource 'projects/.../regions/asia-northeast1/sslCertificates/tf-adv-cm27-gce-cert' was not found
```

作成自体はできる（グローバル資源）。リージョンのターゲットプロキシに付けようとすると、`regions/<region>/sslCertificates/` を探しに行って見つからない。

**この出力が直接示すのは「そのリージョンパスに資源が無い」ことだけ。** リージョン SSL 証明書が Google-managed に非対応であること自体は[仕様](https://docs.cloud.google.com/load-balancing/docs/ssl-certificates#google-managed_ssl_certificates)で確認する。観測と仕様は分けて読む。

**「非対応」ではなく「見つからない」と出る。** 原因に気づきにくい。グローバル側に在ることは `gcloud compute ssl-certificates describe <名前> --global --format='yaml(name,type,managed)'` で確かめられる。

### 7. TLS 接続を確認した。グローバル側は ACTIVE の後にも待ちがあった

リージョン側。

```console
$ curl -o /dev/null -w '%{http_code} %{ssl_verify_result}' https://regional.<domain>/
200 0

subject=CN = regional.<domain>
issuer=C = US, O = Google Trust Services, CN = WR3
notBefore=Sep  5 23:52:56 2026 GMT
notAfter=Dec  5 00:48:52 2026 GMT
```

グローバル側は、証明書が ACTIVE になった直後はまだ繋がらない。

```
curl: (35) error:0A000126:SSL routines::unexpected eof while reading
```

**さらに121秒かかった。** これはこの回の観測値で、必ず生じる待ち時間でも製品の上限でもない。「最大30分」という記述は[Compute Engine の Google-managed 証明書の手順](https://docs.cloud.google.com/load-balancing/docs/ssl-certificates/google-managed-certs#step_5_test_with_openssl)にあるもので、[Certificate Manager の手順](https://docs.cloud.google.com/certificate-manager/docs/deploy-google-managed-lb-auth)は証明書とマップエントリの状態を別々に確認させており、今回の構成に当てはめる根拠は無い。

### 8. アタッチ方法がリージョンとグローバルで違う

| | アタッチ先 |
|---|---|
| リージョン | ターゲットプロキシに **直接**（`certificate_manager_certificates`） |
| グローバル | **証明書マップ**経由（`certificate_map`） |

**併用の可否は上下で違う。** リージョン側の `certificate_manager_certificates` は `ssl_certificates` と同時に指定できない。

> sslCertificates and certificateManagerCertificates can't be defined together.

グローバル側の `certificate_map` は `ssl_certificates` と同時に設定できる。[その場合はマップが優先され、Compute Engine の証明書は無視される](https://docs.cloud.google.com/load-balancing/docs/ssl-certificates#configuration_method_rules)。

## Cloud Logging に残るもの

**管理操作は残る。**

```console
$ gcloud logging read 'protoPayload.serviceName="certificatemanager.googleapis.com"' --freshness=4h
CreateDnsAuthorization  projects/.../dnsAuthorizations/tf-adv-cm27-dnsauth-regional
CreateCertificate       projects/.../certificates/tf-adv-cm27-cert-nolb
...
→ 18 件
```

**今回の検索では、発行の状態遷移が見つからなかった。**

```console
$ gcloud logging read 'textPayload=~"ACTIVE|AUTHORIZ|PROVISION"' --freshness=3h
→ 0 件
```

この条件は `textPayload` しか見ていない。[`jsonPayload` や `protoPayload` は別のフィールド](https://cloud.google.com/logging/docs/view/logging-query-language)なので、**この結果だけでは経過ログが無いとは言えない。**

今回は `describe` を繰り返し、`authorizationAttemptInfo` を見て追った。

## 削除方法

```bash
terraform destroy
```

DNS ゾーンごと消える。親ドメイン側の NS レコードも忘れずに外す。

## 注意 / 費用

- 転送ルール2本（リージョン + グローバル）、VM 1台、Cloud DNS 公開ゾーン1つ
- **`enable_global_lb = false` にすると B を作らない。** DNS 認証だけ見たいときはこちらで足りる
- 検証が終わったら速やかに `destroy` する

## 参考

- [Certificate Manager overview](https://cloud.google.com/certificate-manager/docs/overview)
- [Deploy a regional Google-managed certificate with DNS authorization](https://cloud.google.com/certificate-manager/docs/deploy-google-managed-regional)
- [Deploy a global Google-managed certificate with load balancer authorization](https://cloud.google.com/certificate-manager/docs/deploy-google-managed-lb-auth)
- [DNS authorizations](https://cloud.google.com/certificate-manager/docs/dns-authorizations)
- [Google-managed SSL certificates (Compute Engine)](https://cloud.google.com/load-balancing/docs/ssl-certificates/google-managed-certs)
- [google_certificate_manager_certificate](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/certificate_manager_certificate)
- [google_compute_region_target_https_proxy](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_target_https_proxy)
