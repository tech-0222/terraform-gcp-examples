# 04 - Compute Engine インスタンスパラメータ対応

このファイルは **本サンプルの `google_compute_instance.vm`** について、GCP コンソール項目・`gcloud --format=json`・Terraform 属性を対応づけます。

自動生成の `PARAMETER.md`（terraform-docs: Inputs / Outputs / Resources）とは別物です。手で編集してよい参照資料です。

記載は次の一次情報に合わせています。

- [google_compute_instance](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance)
- [Resource: Instance](https://cloud.google.com/compute/docs/reference/rest/v1/instances)
- [IAP TCP forwarding](https://cloud.google.com/iap/docs/using-tcp-forwarding)
- [Service accounts](https://cloud.google.com/compute/docs/access/service-accounts)
- [Shielded VM オプション](https://cloud.google.com/compute/shielded-vm/docs/modifying-shielded-vm)
- [Provider configuration（attribution label）](https://registry.terraform.io/providers/hashicorp/google/latest/docs/guides/provider_reference)

## 凡例

| 記号 | 意味 |
|---|---|
| **明示** | `main.tf` / `network.tf` / 変数で指定している |
| **未指定** | コードに書いておらず、GCP / Provider のデフォルトに任せる |
| **出力** | apply 後に API が割り当てる値（Terraform output または describe） |
| **Instance 外** | Instance リソースに含まれない（Firewall など別リソース） |
| **再作成 ○** | 変更するとインスタンスの replace になりやすい |
| **再作成 −** | 稼働中または停止して更新できることが多い |

値はデフォルト変数（`terraform.tfvars.example`）を前提にしています。`instance_name` や `machine_type` を上書きした場合は読み替えてください。

Provider が「Changing this forces a new resource」と明記しているのは主に `name` と `hostname` です。`machine_type` / Shielded VM / サービスアカウントなどは、本サンプルの `allow_stopping_for_update = true` により **停止して更新**できることがあります。NIC やブートディスクの `initialize_params`、`preemptible` は plan で replace になりやすいです。最終判断は常に `terraform plan` です。

## 確認コマンド

```bash
gcloud compute instances describe "$(terraform output -raw instance_name)" \
  --zone="$(terraform output -raw zone)" \
  --format=json
```

`gcloud` の対象 Project は ADC / `gcloud config` 側で合わせます。`--format=json` のフィールドパスは REST の Instance リソースに合わせています。

---

## 基本情報

| 項目 | 本サンプル | 区分 | 再作成 | Terraform | gcloud パス |
|---|---|---|---|---|---|
| 名前 | `tf-example-gce-01`（`var.instance_name`） | 明示 | ○ | `name`（変更は新リソース） | `name` |
| インスタンス ID | apply 後に割り当て | 出力 | − | output `instance_id` | `id`（Output only） |
| 説明 | 未設定 | 未指定 | − | `description` | `description` |
| 種類 | `compute#instance` | 出力 | − | — | `kind`（常に `compute#instance`） |
| ステータス | apply 後 `RUNNING` を想定 | 出力 | − | （属性）`current_status` | `status`（Output only） |
| 作成時間 | apply 時 | 出力 | − | — | `creationTimestamp`（Output only） |
| ロケーション | `asia-northeast1-a`（`var.zone`） | 明示 | ○ | `zone`。未指定時は provider の zone | `zone`（ゾーン URL） |
| ブートディスクのソースイメージ | Debian 12（`debian-cloud` / family `debian-12`） | 明示 | ○ | `boot_disk.initialize_params.image` | 作成時のみ `disks[].initializeParams.sourceImage`（Input Only）。GET 後の `disks[].source` は **ディスク URL** |
| ブートディスクのアーキテクチャ | イメージ依存（API は `X86_64` または `ARM64`） | 未指定 | ○ | イメージに依存 | `disks[].architecture`（Output only） |
| インスタンス テンプレート | 使わない | 未指定 | − | `google_compute_instance` に `source_instance_template` はない。テンプレート起点は `google_compute_instance_from_template` | 作成時の `sourceInstanceTemplate` |
| MIG 所属 | なし | 未指定 | − | Instance 外（MIG リソース） | ※別コマンド |
| ラベル | `env=test` ほか下記 | 明示 | − | `labels`（non-authoritative。全体は `effective_labels`） | `labels` |
| ネットワークタグ | `iap-ssh` | 明示 | − | `tags`（Firewall の対象識別。Resource Manager タグとは別） | `tags.items[]` |
| 削除からの保護 | 無効 | 未指定 | − | `deletion_protection`（既定 `false`） | `deletionProtection` |
| Confidential VM | 無効 | 未指定 | ○ になりやすい | `confidential_instance_config` | `confidentialInstanceConfig` |

本サンプルのラベル:

```hcl
env        = "test"
system     = "tf-examples"
component  = "compute"
managed_by = "terraform"
example    = "04-compute-engine"
```

google provider 6.x 以降は `add_terraform_attribution_label` の既定が `true` のため、新規作成時に `goog-terraform-provisioned=true` が付くことがあります。本サンプルの `provider` では明示していません。

---

## マシンの構成

| 項目 | 本サンプル | 区分 | 再作成 | Terraform | gcloud パス |
|---|---|---|---|---|---|
| マシンタイプ | `e2-medium`（`var.machine_type`） | 明示 | −（本サンプル） | `machine_type`。更新には停止が必要 | `machineType`（ゾーン付き URL） |
| CPU プラットフォーム | ゾーン / マシンタイプ依存 | 出力 | − | （出力）`cpu_platform` | `cpuPlatform`（Output only。直接指定しない） |
| 最小 CPU プラットフォーム | 未設定 | 未指定 | − | `min_cpu_platform`（更新は停止が必要） | `minCpuPlatform` |
| GPU | なし | 未指定 | ○ になりやすい | `guest_accelerator`。利用時は `on_host_maintenance = TERMINATE` | `guestAccelerators[]` |
| 表示デバイス | 無効 | 未指定 | − | `enable_display`（更新は停止が必要） | `displayDevice.enableDisplay` |

---

## ネットワーク インターフェース

`network_interface` に `access_config` を書いていないため、**外部 IP はありません**。

| 項目 | 本サンプル | 区分 | 再作成 | Terraform | gcloud パス |
|---|---|---|---|---|---|
| NIC 名 | 通常 `nic0` | 出力 | − | 自動 | `networkInterfaces[].name`（Output only。VM は `nicN`、既定 `nic0`） |
| ネットワーク | `tf-example-gce-vpc` | 明示（subnet から推論） | ○ になりやすい | subnet 指定時は `network` 省略可 | `networkInterfaces[].network` |
| サブネットワーク | `tf-example-gce-subnet` | 明示 | ○ になりやすい | `network_interface.subnetwork` | `networkInterfaces[].subnetwork` |
| プライマリ内部 IP | Subnet `10.20.0.0/24` から自動割り当て | 未指定（自動） | ○ になりやすい | `network_interface.network_ip` / output `internal_ip`。未指定なら API が割り当て | `networkInterfaces[].networkIP` |
| エイリアス IP | なし | 未指定 | − | `network_interface.alias_ip_range` | `networkInterfaces[].aliasIpRanges[]` |
| IP スタック | 未指定なら `IPV4_ONLY` | 未指定 | − | `network_interface.stack_type`。未指定時 `IPV4_ONLY` | `networkInterfaces[].stackType` |
| 外部 IP | なし | 明示（`access_config` 省略） | − | 省略するとインターネットから到達できない | `networkInterfaces[].accessConfigs` なし（API: accessConfigs 未指定なら外部インターネットアクセスなし） |
| IP 転送 | オフ | 未指定 | − | `can_ip_forward`（既定 `false`） | `canIpForward` |

Cloud NAT も作らないため、Debian のパッケージミラーなど **VPC 外への一般インターネット通信はできません**。`private_ip_google_access = true` なので Google API への Private Google Access は使えます。IAP TCP forwarding は外部 IP なしでも利用できます。

---

## ファイアウォール（Instance 外）

コンソールの「HTTP / HTTPS トラフィックを許可」は Instance ではなく Firewall ルールです。本サンプルでは HTTP/HTTPS 用ルールは作りません。

| 項目 | 本サンプル | 区分 | Terraform |
|---|---|---|---|
| HTTP (tcp/80) | 許可しない | Instance 外 | `google_compute_firewall` なし |
| HTTPS (tcp/443) | 許可しない | Instance 外 | `google_compute_firewall` なし |
| IAP SSH (tcp/22) | `35.235.240.0/20` → tag `iap-ssh` | 明示 | `google_compute_firewall.allow_iap_ssh`。この範囲は IAP が TCP forwarding に使う送信元 |
| ネットワークタグ | `iap-ssh` | 明示（Instance） | `tags` |

確認例:

```bash
gcloud compute firewall-rules list --filter="network:tf-example-gce-vpc"
```

---

## ストレージ（ブートディスク）

| 項目 | 本サンプル | 区分 | 再作成 | Terraform | gcloud パス |
|---|---|---|---|---|---|
| サイズ | 20 GB | 明示 | ○ になりやすい（`initialize_params` 変更） | `boot_disk.initialize_params.size` | `disks[].diskSizeGb` |
| 種類 | `pd-balanced` | 明示 | ○ になりやすい | `boot_disk.initialize_params.type` | Instance の `disks[].type` は `PERSISTENT` / `SCRATCH`。`pd-balanced` は Disk の type |
| モード | 読み取り / 書き込み | 未指定 | − | 未指定時 `READ_WRITE` | `disks[].mode` |
| インスタンス削除時 | ディスクも削除 | 未指定 | − | `boot_disk.auto_delete`（既定 `true`） | `disks[].autoDelete` |
| CMEK | 使わない。鍵未指定時は Google 管理の暗号化 | 未指定 | ○ | `boot_disk.kms_key_self_link` | `disks[].diskEncryptionKey`（未使用なら通常省略） |

`initializeParams` は API 上 Input Only です。作成後の GET ではソースイメージではなく、作成済みディスクの `source` URL が見えます。

---

## セキュリティとアクセス

| 項目 | 本サンプル | 区分 | 再作成 | Terraform | gcloud パス |
|---|---|---|---|---|---|
| Shielded VM - セキュアブート | コード未指定。GCP 既定は **オフ** | 未指定 | −（停止更新） | `enable_secure_boot`（ブロック指定時の既定 `false`） | `shieldedInstanceConfig.enableSecureBoot` |
| Shielded VM - vTPM | コード未指定。Shielded 対応イメージでは GCP 既定 **オン** | 未指定 | −（停止更新） | `enable_vtpm`（ブロック指定時の既定 `true`） | `shieldedInstanceConfig.enableVtpm` |
| Shielded VM - 整合性モニタリング | コード未指定。Shielded 対応イメージでは GCP 既定 **オン** | 未指定 | −（停止更新） | `enable_integrity_monitoring`（ブロック指定時の既定 `true`） | `shieldedInstanceConfig.enableIntegrityMonitoring` |
| インスタンス固有 SSH 鍵 | 置かない | 未指定 | − | `metadata` の `ssh-keys` | `metadata.items[]` |
| プロジェクト全体の SSH 鍵をブロック | しない | 未指定 | − | `metadata` の `block-project-ssh-keys` | `metadata.items[]` |
| OS Login | 有効 | 明示 | − | `metadata.enable-oslogin = "TRUE"` | `metadata.items[]`（key: `enable-oslogin`） |

`shielded_instance_config` は省略しています。Provider の親引数は「Defaults to disabled」と書きますが、Debian 12 のような Shielded 対応イメージでは、GCP 公式どおり vTPM と整合性モニタリングが有効、Secure Boot が無効で作成されるのが通常です。実値は describe で確認してください。更新は停止中 VM に対する `updateShieldedInstanceConfig` です。

---

## API と ID の管理

| 項目 | 本サンプル | 区分 | 再作成 | Terraform | gcloud パス |
|---|---|---|---|---|---|
| サービス アカウント | ブロックなし。デフォルト Compute Engine SA（`PROJECT_NUMBER-compute@developer.gserviceaccount.com`） | 未指定 | −（停止更新） | `service_account.email` 省略 | `serviceAccounts[].email` |
| Cloud API スコープ | `cloud-platform` ではない。GCP のデフォルト スコープ | 未指定 | −（停止更新） | `service_account` 省略時はスコープを上書きしない | `serviceAccounts[].scopes[]` |

GCP が新しい VM に付けるデフォルト スコープは次です。

- `https://www.googleapis.com/auth/devstorage.read_only`
- `https://www.googleapis.com/auth/logging.write`
- `https://www.googleapis.com/auth/monitoring.write`
- `https://www.googleapis.com/auth/service.management.readonly`
- `https://www.googleapis.com/auth/servicecontrol`
- `https://www.googleapis.com/auth/trace.append`

コンソールの「すべての Cloud API に完全アクセス」（`cloud-platform`）とは異なります。

---

## 管理・可用性（Spot）

学習・短時間検証向けに Spot を明示しています。予告なく停止・回収されることがあります。

| 項目 | 本サンプル | 区分 | 再作成 | Terraform | gcloud パス |
|---|---|---|---|---|---|
| VM プロビジョニング モデル | Spot | 明示 | ○ | `scheduling.provisioning_model = "SPOT"`。このとき `preemptible = true` かつ `automatic_restart = false` が必要 | `scheduling.provisioningModel` |
| プリエンプティブ | オン | 明示 | ○ | `scheduling.preemptible = true`。作成時または停止中のみ設定可 | `scheduling.preemptible` |
| 自動再起動 | オフ | 明示 | − | `scheduling.automatic_restart = false`（preemptible では必須。標準 VM の既定は `true`） | `scheduling.automaticRestart` |
| ホスト メンテナンス | **`TERMINATE` のみ**（ライブマイグレーション不可） | 未指定（API が設定） | − | `scheduling.on_host_maintenance`。標準 VM の既定は `MIGRATE`。preemptible は既定かつ唯一 `TERMINATE` | `scheduling.onHostMaintenance` |
| 更新のための停止許可 | オン | 明示 | − | `allow_stopping_for_update = true`（Terraform 専用。Instance GET の常設フィールドではない） | — |
| 予約アフィニティ | デフォルト | 未指定 | − | `reservation_affinity` | `reservationAffinity` |
| 単一テナンシー | 使わない | 未指定 | ○ | `scheduling.node_affinities` | `scheduling.nodeAffinities` |
| カスタム メタデータ | OS Login のみ | 明示 | − | `metadata` | `metadata` |

---

## バックアップ（Instance 外）

Backup and DR のプランは作成しません。コンソールに「未設定」と出る想定です。

---

## コードで触っていない主な項目

次は意図的にデフォルトのままです。コンソールや JSON には値が出ることがあります。

- Confidential VM
- GPU / 表示デバイス
- エイリアス IP / IP 転送
- 削除保護
- インスタンス固有 SSH 鍵
- CMEK
- リソースポリシー / 専用ホスト
- HTTP/HTTPS Firewall

変更の影響（replace か停止更新か）は、変更前に `terraform plan` で確認してください。

## 公式照合で直した点

| 旧記載 | 公式に合わせた内容 |
|---|---|
| 再作成 ○ をマシンタイプ等にも広く付けていた | `machine_type` は停止更新可。ForceNew 明記は主に `name` / `hostname` |
| `source_instance_template` を `google_compute_instance` の属性として記載 | その属性は無い。テンプレート起点は別リソース |
| `disks[].source` をイメージと読める書き方 | GET 後の `source` はディスク URL。イメージは作成時 Input Only |
| Shielded の説明が曖昧 | Secure Boot オフ、vTPM / 整合性モニタリングはオンが GCP 既定 |
| ホストメンテナンスを「通常 TERMINATE」 | preemptible では **唯一** `TERMINATE` |
| スコープを「google provider 既定」とだけ書いた | GCP の Default scopes 一覧を記載。`cloud-platform` ではない点は正しい |
| `goog-terraform-provisioned` の根拠が弱い | Provider 6.x の `add_terraform_attribution_label` 既定 `true` |
| 非 JSON describe がフィールドを省略すると断定 | JSON パスは REST リソースに合わせると記載 |
