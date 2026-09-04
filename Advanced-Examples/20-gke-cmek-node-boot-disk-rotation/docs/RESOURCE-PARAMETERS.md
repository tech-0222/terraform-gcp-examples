# 20 - リソースパラメータ対応

このファイルは**GKEノードのブートディスクCMEKと鍵ローテーション**について対応づけます。自動生成の`docs/PARAMETER.md`とは別物です。VPC/踏み台の基本部分は`11-gke-private-bastion`と同じ構成のため、ここでは差分を中心に記載します。

一次情報:

- [Google Cloud: Use CMEK with GKE](https://cloud.google.com/kubernetes-engine/docs/how-to/using-cmek)
- [Google Cloud: Rotate a key](https://cloud.google.com/kms/docs/rotate-key)
- [Google Cloud: Customer-managed encryption keys (Compute Engine)](https://cloud.google.com/compute/docs/disks/customer-managed-encryption)
- [google_container_node_pool](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_node_pool)
- [google_kms_crypto_key](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/kms_crypto_key)

## 確認コマンド

```bash
gcloud kms keys versions list \
  --key="$(terraform output -raw kms_key_ring_name | sed 's/-ring$/-boot-disk/')" \
  --keyring="$(terraform output -raw kms_key_ring_name)" \
  --location="$(terraform output -raw region)"

# ノードのブートディスクが参照している鍵バージョン
gcloud compute disks describe DISK_NAME --zone="$(terraform output -raw zone)" \
  --format="value(diskEncryptionKey.kmsKeyName)"
```

## ネットワーク（VPC/踏み台）

`11-gke-private-bastion`と同じ。CIDRのみ再掲する。

| 項目 | 本サンプル |
|---|---|
| GKE Subnet | `10.40.0.0/24`（Pods `10.41.0.0/16`、Services `10.42.0.0/20`） |
| 踏み台Subnet | `10.43.0.0/24` |
| GKEコントロールプレーン | `172.16.4.0/28` |

## google_kms_key_ring / google_kms_crypto_key

| 項目 | 本サンプル | 区分 | Terraform | 備考 |
|---|---|---|---|---|
| location | `asia-northeast1` | 明示 | `location = var.region` | ノードが動くリージョンと一致させる。別ロケーションの鍵ではディスクを暗号化できない |
| purpose | `ENCRYPT_DECRYPT` | 明示 | `purpose` | 対称鍵 |
| 自動ローテーション | 設定しない | 意図的に省略 | （`rotation_period`を書かない） | タイミングを観測するため手動でローテーションする |
| **削除** | **できない** | — | — | `terraform destroy`はstateから外すだけ。キーリングとキーはプロジェクトに残り続ける |

## IAM（サービスエージェント2つ）

| メンバー | ロール | 理由 |
|---|---|---|
| `service-PROJECT_NUMBER@compute-system.iam.gserviceaccount.com` | `roles/cloudkms.cryptoKeyEncrypterDecrypter` | ブートディスクを作るのはCompute Engine。**これがないとノードプール作成が失敗する** |
| `service-PROJECT_NUMBER@container-engine-robot.iam.gserviceaccount.com` | 同上 | GKEがノードプールを管理するときに鍵を参照する |

## google_container_node_pool（v1 / v2）

| 項目 | 本サンプル | 区分 | Terraform | 備考 |
|---|---|---|---|---|
| CMEK | 有効 | 明示 | `node_config.boot_disk_kms_key` | **変更不可**。既存ノードプールを別の鍵に切り替えることはできない |
| 鍵バージョン | 指定しない | — | — | 鍵の**パス**だけを指定する。実際に使われるのは、ノードプール作成時点のprimaryバージョン |
| disk_type | `pd-balanced` | 明示 | `node_config.disk_type` | |
| pool切り替え | フラグ2つ | 明示 | `count = var.keep_v1_node_pool ? 1 : 0` など | applyのみで3フェーズを進められる |

`boot_disk_kms_key`にはバージョン番号を含めない（`.../cryptoKeys/KEY`まで）。どのバージョンで暗号化されるかは、鍵ではなくノードプールを作った時刻で決まる。

## 実測で確認した挙動

| 項目 | 結果 | 備考 |
|---|---|---|
| ローテーション後の既存ディスク | 鍵バージョン1のまま | 自動再暗号化はされない。ノード再作成も起きない |
| ローテーション後の`terraform plan` | **`No changes.`** | 設定には鍵のパスしかなく、バージョンのずれは検知できない |
| 新しいノードプール | 新しい鍵バージョン | 同じ`boot_disk_kms_key`でも、作成時点のprimaryが使われる |
| **旧プールのスケールアウト** | **新しい鍵バージョン** | ノードプールを分けなくても、新ノードなら新バージョンになる |
| 自動修復によるノード再作成 | 新しい鍵バージョン | `compute.instances.repair.recreateInstance`（`system@google.com`） |
| 稼働中に旧鍵バージョンを無効化 | 影響なし | すでに復号済みでマウントされている |
| 無効化後にノードを再起動 | 起動不可 | `HTTPError 400: Cloud KMS error ... is not enabled, current state is: DISABLED` |
| drain移行の断（replicas 1） | 21秒の完全断 | 毎秒サンプリングで測定。前後2点の確認では見えない |
| drain移行の断（2レプリカ+PDB） | 約6秒の窓で5回失敗 | エンドポイント伝播の遅れ。PDBは面倒を見ない |
| drain移行の断（+`preStop: sleep 20`） | 失敗0回 | `terminationGracePeriodSeconds`をsleepより長くする |

## Cloud Loggingに残るもの

| ログ | クエリ | 内容 |
|---|---|---|
| Cloud KMS監査ログ | `protoPayload.serviceName="cloudkms.googleapis.com"` | `CreateKeyRing` / `CreateCryptoKey` / `SetIamPolicy` / `CreateCryptoKeyVersion` / `UpdateCryptoKeyPrimaryVersion` / `UpdateCryptoKeyVersion`（有効化・無効化） |
| ノード再作成 | `protoPayload.methodName="compute.instances.repair.recreateInstance"` | 自動修復の実行者は`system@google.com`。続く削除・作成は`service-PROJECT_NUMBER@container-engine-robot...` |

**ディスク暗号化で鍵が使われた記録（`Encrypt` / `Decrypt`）は既定では残らない。** データアクセス監査ログの有効化が必要（既定で無効、課金対象）。

未指定（デフォルト）の項目はコンソール/APIのデフォルト値に従う。推測での記載はしない。
