# 23 - リソースパラメータ対応

このファイルは**`default_compute_class_enabled`とノード自動プロビジョニング（NAP）**について対応づけます。自動生成の`docs/PARAMETER.md`とは別物です。VPC/踏み台の基本部分は`11-gke-private-bastion`と同じ構成のため、ここでは差分を中心に記載します。

一次情報:

- [Google Cloud: About custom compute classes](https://cloud.google.com/kubernetes-engine/docs/concepts/about-custom-compute-classes)
- [Google Cloud: Node auto-provisioning](https://cloud.google.com/kubernetes-engine/docs/how-to/node-auto-provisioning)
- [google_container_cluster](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_cluster)

## 確認コマンド

```bash
# clusterAutoscaling ではなく autoscaling
gcloud container clusters describe "$(terraform output -raw cluster_name)" \
  --zone="$(terraform output -raw zone)" --format=json | jq '.autoscaling'

kubectl get computeclasses
```

## 名前が3層で違う

| 層 | 名前 |
|---|---|
| Terraform | `cluster_autoscaling.default_compute_class_enabled` |
| REST API | `clusterAutoscaling.defaultComputeClassConfig.enabled` |
| コンソール | Autopilot compute class compatibility |
| **`gcloud describe`の出力** | **`autoscaling.defaultComputeClassConfig.enabled`** |

`--format="yaml(clusterAutoscaling)"`と書くと`null`が返ります。出力上のキーは`autoscaling`です。

## cluster_autoscaling

| 項目 | 本サンプル | 区分 | Terraform | 備考 |
|---|---|---|---|---|
| NAP | 有効 | 明示 | `enabled = true` | これがないとオートスケーラがノードプールを作れず、compute classに作用対象がない |
| 対象スイッチ | 変数 | 明示 | `default_compute_class_enabled` | `false`のときAPI上は**空オブジェクト**。`enabled: false`とは出ない |
| CPU上限 | `12`（既定） | 明示 | `resource_limits` | 小さすぎると`no.scale.up.nap.pod.zonal.resources.exceeded`でスケールしない |
| メモリ上限 | `48`（既定） | 明示 | `resource_limits` | 同上 |
| ノードのSA | 専用SA | 明示 | `auto_provisioning_defaults.service_account` | 既定SAを使わない |
| プロファイル | 未指定 | 省略 | — | `BALANCED`になる |

`enable_autopilot`とは別物です。あちらはクラスタ全体をAutopilotにします。こちらはStandardのまま、オートスケーラのマシン選択だけを変えます。

## ComputeClass（Kubernetesリソース、Terraform管理外）

| 項目 | 内容 |
|---|---|
| CRD | `computeclasses.cloud.google.com`（`v1`）。スイッチのON/OFFに関係なく存在する |
| GKE提供分 | `autopilot` / `autopilot-arm` / `autopilot-spot` の3つ |
| **`default`** | **GKEは作らない。自分で作る必要がある** |

`k8s/02-default-computeclass.yaml`が`default`の例です。これを作らない限り、スイッチを有効にしても挙動は変わりません。

## 実測で確認した挙動

| 項目 | 結果 | 備考 |
|---|---|---|
| `false`時のAPI表現 | `defaultComputeClassConfig: {}` | 空オブジェクト |
| `true`時のAPI表現 | `{"enabled": true}` | |
| 切り替え | **in-place更新** | `0 added, 1 changed, 0 destroyed`。クラスタ再作成なし |
| `true`にしたときの`default`生成 | **されない** | `autopilot`系3つのまま |
| `true` + 自作`default`（n2） | 指定なしPodが**n2**へ | 自作前はe2 |
| `false` + `default`（c3） | **e2**を新規作成 | ComputeClassを無視 |
| 既存ノード・Podへの影響 | なし | 切り替えても動かない |

## Cloud Loggingに残るもの

| ログ | クエリ | 内容 |
|---|---|---|
| オートスケーラの判断 | `logName=~"cluster-autoscaler-visibility" AND resource.labels.cluster_name="CLUSTER"` | `decision.scaleUp` / `noDecisionStatus.noScaleUp` / `noScaleDown` |
| GKE監査ログ | `protoPayload.serviceName="container.googleapis.com"` | `UpdateCluster`（スイッチ切り替えを含む） |

**スケールアップしない理由は`kubectl describe`に出ません。** `describe`はスケジューラの言い分（`Insufficient cpu`など）しか見せず、オートスケーラが何を検討して何を却下したかはこのログにしかありません。

```json
{"messageId": "no.scale.up.nap.pod.zonal.resources.exceeded", "parameters": ["asia-northeast1-a"]}
{"messageId": "no.scale.up.mig.failing.predicate", "parameters": ["NodeResourcesFit", "Insufficient cpu", "Insufficient memory"]}
```

未指定（デフォルト）の項目はコンソール/APIのデフォルト値に従う。推測での記載はしない。
