# 検証のやり方

`CLAUDE.md` の「検証フロー」の詳細。**規約はあちらにあり、ここには調べ方と実例を置く。**

## メトリクスが空だったとき

**「取れない」を実測だけで結論づけない。** マネージド収集は集めるメトリクスが公式に列挙されており、載っていなければ取れないのが仕様になる。

| 対象 | 一覧 |
|---|---|
| GKE の kube state metrics | [Collect and view kube state metrics](https://cloud.google.com/kubernetes-engine/docs/how-to/kube-state-metrics) |
| GKE の cAdvisor / kubelet | [cAdvisor and kubelet metrics](https://cloud.google.com/kubernetes-engine/docs/how-to/cadvisor-kubelet-metrics) |
| 一覧に無いものを足す | [Collect specific Prometheus metrics](https://cloud.google.com/kubernetes-engine/docs/how-to/collect-specific-prometheus-metrics) |

**自前デプロイ用のエクスポーター設定（`stackdriver/docs/managed-prometheus/exporters/`）と、GKE 組み込みの一覧は別物。** 取り違えると説明が合わなくなる。

実際に何が入っているかは名前で列挙できる。

```bash
curl -s -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  "https://monitoring.googleapis.com/v1/projects/${PROJECT}/location/global/prometheus/api/v1/label/__name__/values"
```

`28-gke-pod-eviction` では、`kube_pod_status_reason` が0件だった理由を「実測から言えるのは組み込みの収集が狭いということ」と書いた。**実際は上の一覧に載っていないだけで、公式に文書化されていた。**

## 時系列の引き方

`gcloud monitoring` にあるのは `dashboards` / `policies` / `snoozes` / `uptime` の4グループで、**時系列を引くサブコマンドが無い。**

```bash
# GCP ネイティブのメトリクス
curl -s -G -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  "https://monitoring.googleapis.com/v3/projects/${PROJECT}/timeSeries" \
  --data-urlencode 'filter=metric.type="kubernetes.io/node/status_condition"' \
  --data-urlencode "interval.startTime=${ST}" --data-urlencode "interval.endTime=${END}"

# GMP の PromQL（別エンドポイント。互換ではない）
curl -s -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  "https://monitoring.googleapis.com/v1/projects/${PROJECT}/location/global/prometheus/api/v1/query" \
  --data-urlencode 'query=up'
```

**時系列はクラスタを消したあとも残る。** destroy 後に確かめ直したいことが出たら、まずこれを試す。

## Cloud Logging を必ず確認する

`kubectl describe` や `gcloud ... operations` だけで終わらせない。それらに出ない情報がログにある。

| サンプル | 表面的な症状 | ログで分かったこと |
|---|---|---|
| `23-gke-default-compute-class` | `kubectl describe pod` は `FailedScheduling` のみ | `no.scale.up.nap.pod.zonal.resources.exceeded` — NAPのCPU上限 |
| `20-gke-cmek-node-boot-disk-rotation` | ノードが復旧していた | `compute.instances.repair.recreateInstance` — GKEの自動修復 |

```bash
# 監査ログ（管理操作）
gcloud logging read 'protoPayload.serviceName="SERVICE.googleapis.com"' --limit=10 --freshness=2h

# GKEオートスケーラの判断（スケールしない理由も出る）
gcloud logging read 'logName=~"cluster-autoscaler-visibility" AND resource.labels.cluster_name="CLUSTER"' --limit=5 --freshness=2h

# Podのイベント
gcloud logging read 'resource.type="k8s_pod" AND jsonPayload.reason="REASON"' --limit=10 --freshness=2h

# コンテナのログ
gcloud logging read 'resource.type="k8s_container" AND resource.labels.pod_name=~"PREFIX"' --limit=10 --freshness=2h
```

**0件だった場合も結果として記録する。** 「ログに残らない」こと自体が運用上の判断材料になる。

- `19-gke-secret-manager-csi`: Secret Manager の `AccessSecretVersion`（値の読み取り）は残らない
- `20-gke-cmek-node-boot-disk-rotation`: Cloud KMS の `Encrypt` / `Decrypt`（鍵の利用）は残らない

どちらもデータアクセス監査ログが既定で無効なためで、追跡には明示的な有効化が要る。

## 名前で躓いた例

| 書きたかったこと | 実際 |
|---|---|
| `kubelet_evictions_total` | 名前は `kubelet_evictions`。`_total` は OpenMetrics 形式のときだけ |
| `eviction_signal="memory.available"` | ラベル側は `allocatableMemory.available` |
| `memory_type=evictable` = 退避で回収できるメモリ | カーネルが容易に回収できるメモリの分類 |

**0件や直感に合わない値を見たら、綴りと定義を先に疑う。**
