# 22 - リソースパラメータ対応

このファイルは**ノードプールのSURGEアップグレード**について対応づけます。自動生成の`docs/PARAMETER.md`とは別物です。`21-gke-blue-green-node-pool-upgrade`と同じ構成で、`upgrade_settings`だけが違います。

一次情報:

- [Google Cloud: Node pool upgrade strategies](https://cloud.google.com/kubernetes-engine/docs/concepts/node-pool-upgrade-strategies)
- [google_container_node_pool](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_node_pool)

## 確認コマンド

```bash
gcloud container node-pools describe "$(terraform output -raw node_pool_name)" \
  --cluster="$(terraform output -raw cluster_name)" \
  --zone="$(terraform output -raw zone)" --format="yaml(upgradeSettings)"
```

## 21との差分

| 項目 | 21（Blue/Green） | 22（SURGE） |
|---|---|---|
| `strategy` | `BLUE_GREEN` | `SURGE` |
| 併用する属性 | `blue_green_settings` | `max_surge` / `max_unavailable` |
| `master_version` | 1段先 | **2段先**（設定を変えて2回上げるため） |

それ以外（VPC、踏み台、CMEK、ノード数、ワークロード、計測方法）は21と同一にしてあります。比較を成立させるためです。

## upgrade_settings（SURGE）

| 項目 | 本サンプル | Terraform | GKE API | 備考 |
|---|---|---|---|---|
| 戦略 | `SURGE` | `upgrade_settings.strategy` | `upgradeSettings.strategy` | GKEの既定。`blue_green_settings`とは併用不可 |
| 追加できるノード数 | `1` | `max_surge` | `upgradeSettings.maxSurge` | 通常サイズを超えて足せる数。増やすと速くなり、その間のノード代が増える |
| 同時に落とせるノード数 | `0` | `max_unavailable` | `upgradeSettings.maxUnavailable` | 既定値`0`はAPIの出力に現れない |

**両方を0にはできない。** 進めなくなるため、`variables.tf`のvalidationで弾いています。

`upgrade_settings`の変更はノードを作り直さず、in-placeで反映されます。

## 実測で確認した挙動

| 項目 | 結果 | 備考 |
|---|---|---|
| `max_surge=1` の置換 | 2→3→2→3→2 | **先に足してから落とす。** 稼働ノードが初期値を下回らない |
| `max_surge=1` の断 | **359/359が200、失敗0回** | 5分56秒 |
| `max_surge=0` の置換 | 2→1→2 | ノードは増えず、一時的に減る |
| `max_surge=0` の断 | **19秒の完全断** | 3分20秒。速いが止まる |
| `upgrade_settings`の変更 | in-place | `0 added, 1 changed, 0 destroyed` |
| アップグレード後の`terraform plan` | `No changes.` | `lifecycle.ignore_changes = [version]`が効く |

### max_surge = 0 で断が出る理由

```
FailedScheduling  0/2 nodes are available:
  1 node(s) didn't match pod anti-affinity rules, 1 node(s) were unschedulable.
```

追加ノードがないため、cordonしたノードから退避したPodの行き先がない。レプリカが減った状態で次のノードの番が来て、受け先がゼロになる。

内部LB側でも縮退が起きる。

```
Warning  EnterDegradedMode  Entering degraded mode for NEG ... sync err
Warning  AttachFailed       Error 400: Invalid value for field 'resource.instance'
                            Couldn't find instance with a specified name ...
```

`max_surge = 0`は「追加ノードが不要」ではなく「余力を持たずに入れ替える」設定と読む。

## 3方式の比較

| 観点 | Blue/Green | SURGE `max_surge=1` | SURGE `max_surge=0` |
|---|---|---|---|
| 断 | 0回 | 0回 | 19秒の完全断 |
| 所要時間 | 17分3秒 | 5分56秒 | 3分20秒 |
| 最大ノード数（2ノード時） | 4（倍） | 3（+1） | 2 |
| Pod IP・vCPUの一時消費 | 倍 | +1ノード分 | なし |
| ロールバック | soak期間中は可能 | 不可 | 不可 |
| 手順 | cancel → rollback | 単純 | 単純 |

未指定（デフォルト）の項目はコンソール/APIのデフォルト値に従う。推測での記載はしない。
