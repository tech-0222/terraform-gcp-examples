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

## 過去の検証で踏んだこと

個々のサンプル固有の事実は各 README にある。ここには、別の検証でも同じ形で起きうるものだけを置く。

### 前提を疑う

- **参考にした手順や広く紹介されている手順は仮説として扱う。** 予算の Pub/Sub 通知でサービスエージェントに `roles/pubsub.publisher` を付ける説明が多いが、候補のアドレスはいずれも存在せず、付与なしで通知は届いた（`26`）。ブートディスクの CMEK も「ノードプールを作り直す」という前提で進めていたが、鍵バージョンを進めるだけならスケールアウトで新バージョンになった（`20`）
- **一度しか実行していない結果は、再現性のある挙動とは限らない。** 以前の検証で得た「Blue=鍵v1 / Green=鍵v2」は、KMS の primary 切替の伝播がたまたま間に合っただけだった（`21`）
- **エラーメッセージだけで推測せず、`--help` を読む。** `gcloud container node-pools rollback` は soak 中に拒否される。ヘルプに「cancel か失敗のあとに使う」とあり、正しくは `operations cancel` → `rollback` だった（`21`）
- **REST と gcloud でフィールド名が違う。** `clusterAutoscaling` は `gcloud container clusters describe` の出力では `autoscaling`。REST の名前で書くと `null` が返る（`23`）

### apply の成功は中身を保証しない

- **`terraform apply` と `plan` の差分なしは、構築の完了ではない。** Ansible 検証では35リソースの作成に成功した一方、VM の中では role が見つからず失敗していた（`25`）
- **Terraform が検知できないずれがある。** CMEK の鍵バージョンは設定に現れず、ローテーション後も `plan` は `No changes.`。`gcloud compute disks list` で見るしかない（`20`）
- **「前後2点」の確認では断は見えない。** drain の前後だけを見ると疎通は続いていたが、毎秒サンプリングすると21秒の完全断があった（`20`）
- **許可リストは、拒否されることまで確かめる。** 実在しない IP（RFC 5737 の `203.0.113.1/32`）を一時的に設定し、接続が拒否されることを見てから戻す（`15`）

### destroy と残存物

- **destroy しても、すぐに空にならないリソースがある。** Workload Identity Pool と Provider は30日間ソフトデリートで残り、同じ ID の再 apply が `409` になる。`undelete` して `import` すれば戻せる（`05`）
- **Cloud KMS のキーリングと鍵は削除できない。** `destroy` は鍵バージョンの破棄をスケジュールするので、import して再利用しても使えない。再検証は別名で行う（`20`）
- **プロジェクトの外にあるリソースは、残存確認の穴になる。** 予算は請求先アカウント配下で、`terraform state list` が0件でも消えたことにならない（`26`）
- **長い GKE 操作の途中で Terraform の HTTP2 接続が切れることがある。** `apply` はエラーでも、GCP 側ではクラスタができている場合がある。state は tainted になり、次の `apply` は作り直しになる。`gcloud` で実物を見てから判断する（`16`）

### 環境とツール

- **`cmd | tee file` の直後の `$?` は `tee` の終了コード。** 失敗したコマンドを成功と記録した。`${PIPESTATUS[0]}` を使う
- **`curl ifconfig.me` は IPv6 を返すことがある。** 許可リストに IPv4 を入れるなら `curl -4` を使う（`15`、`28`）
- **Cloud Run の `*.run.app` では `/healthz` が予約されている。** Google Frontend が 404 を返し、コンテナに届かない。`/health` なら届く（`06`）
- **`e2-small` では Secret Manager CSI が載らない。** CSI の DaemonSet と標準コンポーネントで CPU が埋まり、アプリの Pod が `Pending` になる（`19`）
- **Dataplane V2 のクラスタに `network_policy` アドオンを設定しない。** `ADVANCED_DATAPATH` と併用できず apply が失敗する（`16`）
- **非対話の SSH 経由で `kubectl run --rm -it` を使わない。** TTY が無く不安定になる。`sleep` させた Pod に `kubectl exec` する（`16`）

### 監査ログに残らない操作

上の「Cloud Logging を必ず確認する」に挙げた2件に加え、予算（Cloud Billing）の作成・更新も0件だった（`26`）。コストのガードレールを外した記録が追えない。
