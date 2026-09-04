# 21 - リソースパラメータ対応

このファイルは**ノードプールのBlue/Greenアップグレード**について対応づけます。自動生成の`docs/PARAMETER.md`とは別物です。VPC/踏み台の基本部分は`11-gke-private-bastion`、CMEKの部分は`20-gke-cmek-node-boot-disk-rotation`と同じ構成のため、ここでは差分を中心に記載します。

一次情報:

- [Google Cloud: Node pool upgrade strategies](https://cloud.google.com/kubernetes-engine/docs/concepts/node-pool-upgrade-strategies)
- [Google Cloud: Rotate a key](https://cloud.google.com/kms/docs/rotate-key)
- [google_container_node_pool](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_node_pool)

## 確認コマンド

```bash
gcloud container node-pools describe "$(terraform output -raw node_pool_name)" \
  --cluster="$(terraform output -raw cluster_name)" \
  --zone="$(terraform output -raw zone)" --format="yaml(upgradeSettings)"

# アップグレード中のBlue/Green共存
kubectl get nodes -o custom-columns=NAME:.metadata.name,VERSION:.status.nodeInfo.kubeletVersion,SCHED:.spec.unschedulable
```

## ネットワーク（VPC/踏み台）

`11-gke-private-bastion`と同じ。CIDRのみ再掲する。

| 項目 | 本サンプル |
|---|---|
| GKE Subnet | `10.40.0.0/24`（Pods `10.41.0.0/16`、Services `10.42.0.0/20`） |
| 踏み台Subnet | `10.43.0.0/24` |
| GKEコントロールプレーン | `172.16.4.0/28` |

Blue/Greenアップグレード中はノードが一時的に倍になる。PodのセカンダリレンジとIPの空きに余裕を持たせる。

## google_container_cluster（バージョン指定）

| 項目 | 本サンプル | 区分 | Terraform | 備考 |
|---|---|---|---|---|
| リリースチャンネル | `REGULAR` | 明示 | `release_channel.channel` | `master_version`と`node_pool_version`はこのチャンネルで有効なものに限る |
| コントロールプレーン | `1.35.7-gke.1150000` | 明示 | `min_master_version` | 作成時のみ有効。ノードプールより**新しく**しないとアップグレード先がない |

## google_container_node_pool

| 項目 | 本サンプル | 区分 | Terraform | 備考 |
|---|---|---|---|---|
| バージョン | `1.35.7-gke.1027000` | 明示 | `version` | 意図的にmasterより古くする |
| 自動アップグレード | 無効 | 明示 | `management.auto_upgrade = false` | 検証したいタイミングで打つため |
| `version`の追跡 | 無視 | 明示 | `lifecycle.ignore_changes = [version]` | アップグレードは`gcloud`で打つ。これがないと次のapplyで巻き戻る |
| CMEK | 有効 | 明示 | `node_config.boot_disk_kms_key` | 鍵の**パス**のみ。バージョンはディスク作成時に決まる |

## upgrade_settings（Blue/Green）

| 項目 | 本サンプル | Terraform | GKE API | 備考 |
|---|---|---|---|---|
| 戦略 | `BLUE_GREEN` | `upgrade_settings.strategy` | `upgradeSettings.strategy` | `max_surge` / `max_unavailable`とは**併用不可**。あちらはSURGE用 |
| soak期間 | `600s` | `blue_green_settings.node_pool_soak_duration` | `blueGreenSettings.nodePoolSoakDuration` | **ロールバック可能な猶予**。満了するとblueが削除され、ロールバックできなくなる。GKEの既定は`3600s` |
| バッチ割合 | `0.5` | `standard_rollout_policy.batch_percentage` | `standardRolloutPolicy.batchPercentage` | **0〜1の割合。パーセントではない** |
| バッチ間の待機 | `60s` | `standard_rollout_policy.batch_soak_duration` | `standardRolloutPolicy.batchSoakDuration` | 次のバッチに進む前の猶予 |

## 検証用のKubernetesリソース（Terraform管理外）

| ファイル | 用途 |
|---|---|
| `k8s/01-nginx.yaml` | 2レプリカ + `podAntiAffinity` + PDB + `preStop`。`20`で断が0になった構成をそのまま使う |
| `k8s/02-curl.yaml` | クラスタ内からの疎通確認用 |
| `k8s/03-nginx-ilb.yaml` | 内部LB。**踏み台から測るために要る** |

Blue/Greenアップグレードはblueノードを全て入れ替えるため、クラスタ内に置いたプローブPodは計測対象と一緒に退避される。踏み台から内部LB経由で測ると、アップグレード全体を通して観測できる。

## 実測で確認した挙動

| 項目 | 結果 | 備考 |
|---|---|---|
| Blue/Greenの共存 | 同一ノードプール内に新旧K8sバージョンが並存 | ノードプールは1つのまま。名前のプレフィックス（インスタンステンプレートのハッシュ）で見分ける |
| 移行中の断（1回目、17分3秒） | **900/900が200、失敗0回** | `preStop`などの作り込みは`20`と同じ。Blue/Green側の追加設定は不要 |
| soak満了 | blueが自動削除される | `600s`の設定どおり |
| **`rollback`単体** | **拒否される** | `Cluster is running incompatible operation`。soakフェーズ中でも同じ |
| **キャンセル → `rollback`** | **成功**（3分10秒） | `rollback`は「キャンセル済みまたは失敗したアップグレードの後に使う」もの |
| ロールバック後 | 旧バージョンに復帰 | greenを削除、blueをuncordon、Podも戻る |
| 移行〜キャンセル〜ロールバックの断 | **631/631が200、失敗0回** | ロールバック経路も無停止だった |
| アップグレード後の`terraform plan` | インフラ差分なし | `lifecycle.ignore_changes = [version]`が効く。変わるのは出力値`master_version`のみ |
| **鍵バージョンの反映** | **ローテーション直後は旧バージョン** | +17秒に作られたノードはv1、+18分はv2。同じプール・同じテンプレートで割れた |

### UPGRADE_STAGE で進行段階が読める

```bash
gcloud container operations describe OPERATION_ID --zone=ZONE \
  --format="value(progress.metrics[0].stringValue,status)"
```

`CORDONING_BLUE_POOL` → `DRAINING_BLUE_POOL` → `NODE_POOL_SOAKING` → （blue削除）と進む。soak窓に入ったかどうかはこれで判断する。

### 鍵バージョンの伝播遅延

インスタンステンプレートが持つのは鍵の**パスのみ**でバージョンを含まない。バージョンはディスク作成時のprimaryで決まるが、primaryの切替には遅延がある。

> When you change the primary key version, the change typically becomes consistent within 1 minute. However, this change can take up to 3 hours to propagate in exceptional cases.
> （[Rotate a key](https://cloud.google.com/kms/docs/rotate-key)）

ローテーションしてすぐノードを作り直しても、新しい鍵バージョンになるとは限らない。移行の完了は`gcloud compute disks list`で確認する。

未指定（デフォルト）の項目はコンソール/APIのデフォルト値に従う。推測での記載はしない。
