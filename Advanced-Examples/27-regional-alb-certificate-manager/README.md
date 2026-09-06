# 27-regional-alb-certificate-manager

Certificate Manager の **DNS 認証** と **LB 認証** を並べて実測する。

リージョン外部 Application Load Balancer では、Compute Engine のマネージド SSL 証明書が使えない。

> Compute Engine Google-managed SSL certificates aren't supported for regional external Application Load Balancers, regional internal Application Load Balancers, or cross-region internal Application Load Balancers.

つまりリージョン ALB で Google 発行の証明書を使うなら、Certificate Manager が唯一の選択肢になる。

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

委任しないと DNS 認証の CNAME が引けず、証明書は PENDING のまま進まない。

## 使い方

```bash
cp terraform.tfvars.example terraform.tfvars   # dns_zone_domain を埋める
terraform init
terraform apply
terraform output name_servers                  # 親ドメインの NS に設定する
```

**Certificate Manager API を有効化した直後は失敗することがある。**

```
Certificate Manager API has not been used in project ... before or it is disabled.
"reason": "SERVICE_DISABLED"
```

`google_project_service` は有効化の API 呼び出しが成功した時点で完了する。実際に使えるようになるまでには伝播の時間が要る。**もう一度 `apply` すれば通る。**

## 実測結果

### 1. 発行までの時間は、ほぼ DNS の伝播待ち

| | ACTIVE まで |
|---|---|
| 初回（委任した直後） | **38分53秒** |
| 2回目（委任済みのゾーンに追加） | **4分12秒** |

同じプロジェクト、同じゾーン、同じ手順で **9倍以上の差**が出た。違いは委任してからの経過時間だけ。

「最大24時間」といった記述は Google の発行処理ではなく、**DNS の伝播を含めた上限**と読むのが実態に合う。

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

LB 認証では原理的にできない。認証の条件が「そのホスト名の A レコードがロードバランサを指していること」だから。**既存サイトを LB に載せ替えるとき、DNS 認証なら切り替え前に証明書を用意できる。**

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

### 6. Compute Engine のマネージド証明書はリージョンに存在できない

```
ERROR: Could not fetch resource:
 - The resource 'projects/.../regions/asia-northeast1/sslCertificates/tf-adv-cm27-gce-cert' was not found
```

作成自体はできる（グローバル資源）。リージョンのターゲットプロキシに付けようとすると、`regions/<region>/sslCertificates/` を探しに行って見つからない。

**「非対応」ではなく「見つからない」と出る。** 原因に気づきにくい。

### 7. TLS は張れるが、証明書が ACTIVE になった時点ではまだ張れない

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

**さらに121秒かかった。** 公式に「証明書とドメインが active になってから、ロードバランサが使い始めるまで最大30分」とある箇所。

### 8. アタッチ方法がリージョンとグローバルで違う

| | アタッチ先 |
|---|---|
| リージョン | ターゲットプロキシに **直接**（`certificate_manager_certificates`） |
| グローバル | **証明書マップ**経由（`certificate_map`） |

`ssl_certificates` とは併用できない。

> sslCertificates and certificateManagerCertificates can't be defined together.

## Cloud Logging に残るもの

**管理操作は残る。**

```console
$ gcloud logging read 'protoPayload.serviceName="certificatemanager.googleapis.com"' --freshness=4h
CreateDnsAuthorization  projects/.../dnsAuthorizations/tf-adv-cm27-dnsauth-regional
CreateCertificate       projects/.../certificates/tf-adv-cm27-cert-nolb
...
→ 18 件
```

**発行の状態遷移は残らない。**

```console
$ gcloud logging read 'textPayload=~"ACTIVE|AUTHORIZ|PROVISION"' --freshness=3h
→ 0 件
```

`AUTHORIZING` → `FAILED` → `AUTHORIZED` → `ACTIVE` の遷移に対応するログは無い。**「なぜ止まっているか」はログからは追えない。** `describe` を繰り返し、`authorizationAttemptInfo` を見るしかない。

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
