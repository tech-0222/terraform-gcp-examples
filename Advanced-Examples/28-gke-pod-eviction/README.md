# 28-gke-pod-eviction

kubelet がノードの逼迫を検知して Pod を退避（Eviction）する挙動を、**実際に起こして**観察する。

- **MemoryPressure**: ノードの空きメモリがしきい値を下回る
- **DiskPressure**: nodefs の空き容量がしきい値を下回る

観測は4系統すべてで行う。**どれか1つでは実運用で使えない。**

| 系統 | 見るもの |
|---|---|
| `kubectl` / kubelet | 実際に何が起きたか |
| `gcloud container` | サービス側から見た状態 |
| `gcloud logging` | ログに何が残るか（0件も結果） |
| Cloud Monitoring / GMP | メトリクスが取れるか |

採取は `scripts/collect.sh` にまとめてある。**クラスタを destroy する前に実行する。**

## 何を検証するか

| # | 検証すること |
|---|---|
| 1 | GKE の退避しきい値の既定値はいくつか |
| 2 | **どの Pod から退避されるか** |
| 3 | 退避された Pod の `status` と Event に何が出るか |
| 4 | Cloud Logging に何が残るか |
| 5 | **GMP で退避を検知できるか** |

## 構成

ノード1台のゾーンクラスタ。

```
e2-standard-2 (8GB)
  capacity     8146868Ki
  kubeReserved 1819Mi
  allocatable  6170292Ki
```

QoS クラスを3つ並べ、そこへメモリを掴む Pod とディスクを埋める Pod を投げる。

| Pod | QoS | requests | 実使用 |
|---|---|---|---|
| `besteffort` | BestEffort | なし | ほぼ0 |
| `burstable` | Burstable | 64Mi | ほぼ0 |
| `guaranteed` | Guaranteed | 128Mi（= limits） | ほぼ0 |
| `hog` | Burstable | 64Mi | 6GB |
| `diskfill` | BestEffort | なし | ディスク20GB |

## 前提条件

- Google Cloud CLI、Terraform
- Billing が有効な検証用プロジェクト
- 実行元のグローバル **IPv4**
- 検証時のバージョン：Terraform 1.14.3、google 7.x、GKE v1.35.7-gke.1027000

**`authorized_ipv4_cidr` は IPv4 で指定する。** `curl -s https://ifconfig.me` は環境によって IPv6 を返し、plan で落ちる。

```
Error: expected master_authorized_networks_config.0.cidr_blocks.0.cidr_block
       to contain a valid network Value, expected 240f:73::/32, got 240f:73:...
```

`curl -s -4 https://ifconfig.me` のように IPv4 を明示する。

## 使い方

```bash
cp terraform.tfvars.example terraform.tfvars
terraform init && terraform apply
eval "$(terraform output -raw get_credentials)"

kubectl apply -f k8s/01-qos.yaml
kubectl apply -f k8s/02-memory-hog.yaml     # MemoryPressure
kubectl apply -f k8s/03-disk-fill.yaml      # DiskPressure

bash scripts/collect.sh                     # 4系統をまとめて採取
terraform destroy
```

## 実測結果

### 1. GKE の既定のしきい値

```console
$ kubectl get --raw "/api/v1/nodes/<NODE>/proxy/configz"
evictionHard:
  memory.available: 100Mi
  nodefs.available: 10%
  nodefs.inodesFree: 5%
  pid.available: 10%
evictionPressureTransitionPeriod: 5m0s
kubeReserved:
  cpu: 70m
  ephemeral-storage: 15Gi
  memory: 1819Mi
```

**メモリのしきい値は 100Mi しかない。** 切ってから退避が始まるので、余裕はほとんどない。

`ephemeral-storage` の予約が 15Gi ある。30GB のディスクでも、Pod が使えるのは実質10GB程度になる。

### 2. 退避される Pod は QoS だけでは決まらない

メモリ逼迫のとき。

```text
09:38:19  besteffort
  The node was low on resource: memory. Threshold quantity: 100Mi, available: 17348Ki.
  Container app was using 188Ki, request is 0, has larger consumption of memory.
```

ディスク逼迫のとき。

```text
09:45:23  hog
  The node was low on resource: ephemeral-storage. Threshold quantity: 2722654248,
  available: 1600496Ki.
09:45:42  diskfill
  ... available: 371692Ki. Container fill was using 40Ki, request is 0,
  has larger consumption of ephemeral-storage.
```

メッセージに**しきい値・そのときの空き・そのコンテナの使用量と requests** が入っている。**QoS クラスは書かれていない。**

[公式](https://kubernetes.io/docs/concepts/scheduling-eviction/node-pressure-eviction/)の順位付けは ①requests を超えているか ②Pod Priority ③requests に対する超過量 の3つ。**「kubelet は退避順序の決定に QoS クラスを使わない」と明記されている。** ディスク逼迫でも同じ3基準で、測る対象がファイルシステム使用量に変わる。

`requests` が 0 の BestEffort は、**188Ki 使っただけで「超過」になる。**

```console
$ kubectl -n evict-test get pods \
    -o custom-columns='NAME:.metadata.name,QOS:.status.qosClass,STATUS:.status.phase,REASON:.status.reason'
NAME         QOS          STATUS    REASON
besteffort   BestEffort   Failed    Evicted
burstable    Burstable    Running   <none>
diskfill     BestEffort   Failed    Evicted
guaranteed   Guaranteed   Running   <none>
hog          Burstable    Failed    Evicted
```

生き残った2つはどちらも requests を宣言していて、実使用がそれを下回っている。

なお、e2-medium で回した別の日には順序が変わった。1回目は `besteffort` → `hog`、2回目は `hog` のみ。**1回の観測で退避順を結論づけてはいけない。**

### 3. DiskPressure は 208秒で再現できた

`emptyDir` に 20GB 書き込む。`emptyDir` は nodefs 上にあるので、書いた分だけ `nodefs.available` が減る。

```text
09:42:07  diskfill 投入
09:45:35  DiskPressure=True   （208秒）
```

**空きが戻っても `DiskPressure=True` は続く。** `evictionPressureTransitionPeriod` が 5分あるため。今回は10分後に `False` へ戻り、そのとき `nodefs.available` は 17.95GiB（70.8%）まで回復していた。

### 4. kubelet は退避をカウントしている

```console
$ kubectl get --raw "/api/v1/nodes/<NODE>/proxy/metrics" \
    | grep -E '^# TYPE kubelet_evictions |^kubelet_evictions'
# TYPE kubelet_evictions counter
kubelet_evictions{eviction_signal="allocatableMemory.available"} 2
kubelet_evictions{eviction_signal="nodefs.available"} 2

$ ... | grep '^kubelet_eviction_stats_age_seconds_count'
kubelet_eviction_stats_age_seconds_count{eviction_signal="allocatableMemory.available"} 2
kubelet_eviction_stats_age_seconds_count{eviction_signal="containerfs.available"} 2
kubelet_eviction_stats_age_seconds_count{eviction_signal="nodefs.available"} 2
```

**名前は `kubelet_evictions` で `_total` は付かない。** kubelet のソースでは `Subsystem: kubelet` / `Name: evictions` の CounterVec として[登録されている](https://github.com/kubernetes/kubernetes/blob/master/pkg/kubelet/metrics/metrics.go)。`_total` が付くのは OpenMetrics 形式のときだけ。**`_total` 付きで grep すると必ず0件になる。**

`kubelet_eviction_stats_age_seconds` は ALPHA の Histogram で、定義は「統計を収集した時点から、その統計に基づいて Pod が退避された時点までの時間」（[Metrics Reference](https://kubernetes.io/docs/reference/instrumentation/metrics/)）。**判定が走った回数ではない。** `_count` は観測数なので、そのシグナルで実際に退避が起きた回数を表す。

**シグナル名は `allocatableMemory.available`。** `evictionHard` に書く `memory.available` とラベル側の綴りが違う。

### 5. Cloud Logging には残る

```console
$ gcloud logging read '<query>' --freshness=2h
  resource.type="k8s_pod" AND jsonPayload.reason="Evicted"           4 件
  resource.type="k8s_node" AND jsonPayload.reason=~"Evict|Pressure"  8 件
  resource.type="k8s_node" AND jsonPayload.MESSAGE=~"eviction"      36 件
  protoPayload.serviceName="container.googleapis.com"                7 件
```

Pod 側とノード側の両方に残る。**「いつ何がなぜ退避されたか」を追えるのはログだけ。**

### 6. GMP では退避を直接検知できない

これが一番の発見だった。ジョブは全部 `up=1` になる。

```text
up{job="gmp-kubelet-metrics"}   = 1
up{job="gmp-kubelet-cadvisor"}  = 1
up{job="kube-state-metrics"}    = 1
```

それでも、肝心のメトリクスが来ない。

| 取れる | 系列数 | 取れない | 系列数 |
|---|---:|---|---:|
| `kube_pod_status_phase` | 25 | **`kube_pod_status_reason`** | **0** |
| `kubelet_running_pods` | 1 | **`kube_node_status_condition`** | **0** |
| `kubelet_running_containers` | 3 | `kubelet_evictions` | 0 |
| `container_memory_working_set_bytes` | 76 | `kube_pod_container_resource_requests` | 0 |

`kubelet_evictions` はノードの `/metrics` に実在する（上の 4）。**それでも Cloud Monitoring には入らない。**

#### コンポーネントを全部有効にしても増えない

```console
$ gcloud container clusters update tf-adv-evict --zone asia-northeast1-a \
    --monitoring=SYSTEM,POD,DAEMONSET,DEPLOYMENT,HPA,STATEFULSET,STORAGE,CADVISOR,KUBELET
$ gcloud container clusters describe tf-adv-evict --zone asia-northeast1-a \
    --format="value(monitoringConfig.componentConfig.enableComponents)"
SYSTEM_COMPONENTS;STORAGE;HPA;POD;DAEMONSET;DEPLOYMENT;STATEFULSET;CADVISOR;KUBELET
```

| クエリ | 4コンポーネント | 全9コンポーネント |
|---|---:|---:|
| `kube_pod_status_phase` | 25 | 25 |
| `kube_pod_status_reason` | 0 | **0** |
| `kube_node_status_condition` | 0 | **0** |
| `kube_pod_container_resource_requests` | 0 | **0** |
| `kube_node_status_allocatable` | 0 | **0** |
| `kubelet_evictions` | 0 | **0** |

**1つも増えない。設定の問題ではない。**

#### この環境で入っていた kube_* は7種類

```console
$ curl -s -H "Authorization: Bearer $(gcloud auth print-access-token)" \
    "https://monitoring.googleapis.com/v1/projects/${PROJECT}/location/global/prometheus/api/v1/label/__name__/values"
```

全体で 18,624 種類。うち `kube_` で始まるものは、この環境では7つで全部だった。

```text
kube_deployment_spec_replicas
kube_deployment_status_replicas_available
kube_deployment_status_replicas_updated
kube_pod_container_status_ready
kube_pod_container_status_waiting_reason
kube_pod_status_phase
kube_pod_status_unschedulable
```

全コンポーネントを有効にして増えたのは `kube_deployment_*` の3つだけ。`kubelet_` で始まるものは11種類で、**同じノードの `/metrics` が出す119種類のうちの一部**にすぎない。

これは仕様どおりで、GKE のマネージド収集は集めるメトリクスをコンポーネントごとに公開している。

- [kube state metrics を収集して表示する](https://cloud.google.com/kubernetes-engine/docs/how-to/kube-state-metrics)
- [cAdvisor / kubelet メトリクス](https://cloud.google.com/kubernetes-engine/docs/how-to/cadvisor-kubelet-metrics)

この2つの一覧に、退避に関するものは1つも載っていない。**監視の設計は `up` からではなく、この一覧から始める。**

一覧に無いメトリクスは、収集対象を自分で足せば取れる。取り方は出どころで変わる。

- kube-state-metrics 由来（`kube_pod_status_reason`）→ 自分でデプロイして `PodMonitoring` で拾う。手元の kube-prometheus-stack では取れた
- kubelet 由来（`kubelet_evictions`）→ ノードの `/metrics` に既に出ているので、[`ClusterNodeMonitoring`](https://cloud.google.com/kubernetes-engine/docs/how-to/collect-specific-prometheus-metrics) で直接取り込む

```yaml
apiVersion: monitoring.googleapis.com/v1
kind: ClusterNodeMonitoring
metadata:
  name: kubelet-evictions
spec:
  selector:
    matchLabels: {}
  endpoints:
  - path: "/metrics"
    scheme: "https"
    interval: "30s"
    tls:
      insecureSkipVerify: true
    metricRelabeling:
    - action: keep
      sourceLabels: [__name__]
      regex: kubelet_evictions
```

`metricRelabeling` で絞らないと119種類が全部入る。**この設定は今回の検証では試していない。**

退避は phase で間接的に見える。

```promql
kube_pod_status_phase{namespace="evict-test"} == 1
  pod=besteffort phase=Failed   1
  pod=diskfill   phase=Failed   1
  pod=hog        phase=Failed   1
  pod=burstable  phase=Running  1
  pod=guaranteed phase=Running  1
```

ただし `phase=Failed` は退避以外でもなる。**理由まで知るには Cloud Logging が要る。**

### 7. GCP ネイティブのメトリクスは取れる

```console
kubernetes.io/node/memory/used_bytes
  memory_type=evictable      最新 685,723,648
  memory_type=non-evictable  最新 1,502,375,936
kubernetes.io/node/memory/allocatable_utilization
  component=pods memory_type=evictable      最新 0.0267
  component=pods memory_type=non-evictable  最新 0.0771
kubernetes.io/node/ephemeral_storage/used_bytes
                             最新 7,931,101,184
```

**`evictable` は「退避で回収できるメモリ」ではない。** [公式の定義](https://cloud.google.com/monitoring/api/metrics_kubernetes)は「カーネルが容易に回収できるメモリ」で、Pod の退避とは関係しない。実測でも、逼迫の最中に 6.27GB まで上がっていた（allocatable は 6,170,292Ki）。

```text
時刻   evictable      non-evictable
09:43    749,879,296  1,444,921,344
09:44  4,678,520,832  1,430,188,032   ← hog がメモリを掴む
09:45  6,274,232,320  1,466,175,488   ← MemoryPressure=True
09:46    666,390,528  1,478,160,384   ← 退避後
```

kubelet が使う `memory.available` は cgroupfs から取った値から `inactive_file` を除いた別物で、`free -m` とも `evictable` とも一致しない。

**ノード逼迫の監視には `kubernetes.io/node/status_condition` を使う。** `condition` と `status` のラベルを持ち、Pressure の期間がそのまま取れる。

```text
condition=MemoryPressure  status=True   True の期間 09:40:00 〜 09:45:00
condition=DiskPressure    status=True   True の期間 09:47:00 〜 09:52:00
```

### 8. `gcloud monitoring` に時系列のサブコマンドが無い

```console
$ gcloud monitoring time-series list ...
ERROR: (gcloud.monitoring) Invalid choice: 'time-series'.
Maybe you meant:
  gcloud monitoring dashboards list
  gcloud monitoring policies list
```

`gcloud monitoring` にあるのは `dashboards` / `policies` / `snoozes` / `uptime` の4グループで、時系列を引くサブコマンドが無い。Monitoring API v3 を直接呼び出す。`scripts/collect.sh` はそうしている。

## ローカル（minikube）では再現しきれない

docker ドライバの minikube では、kubelet がコンテナの cgroup 制限ではなく**ホストの値**を見る。

| | kubelet が見る値 | 実際の制限 |
|---|---|---|
| メモリ | 31GB（ホスト） | 6GB（`--memory`） |
| ディスク | 755GB（ホスト） | 12GB（`--disk-size`） |

しきい値をホスト基準に置き換えれば仕組みは確認できるが、**オンプレのノード逼迫をそのまま再現することはできない。**

kvm2 ドライバ（実 VM）も試したが、`network 'mk-evict' already exists` で起動できなかった。libvirt を完全に掃除しても再現する。

## 削除方法

```bash
terraform destroy
```

**GKE は最もコストが高い。検証が終わったら速やかに削除する。**

## 注意 / 費用

- ノード1台（e2-standard-2、既定で Spot）+ GKE のクラスタ管理費
- **e2-medium では GMP の収集コンポーネントが Pending になる。** allocatable が 2.8GB しかなく、退避を起こす余地が残らない
- `auto_repair` と `auto_upgrade` は切ってある。観測中にノードが入れ替わると邪魔になるため
- ディスク検証は 20GB 書き込む

## 参考

- [Node-pressure eviction](https://kubernetes.io/docs/concepts/scheduling-eviction/node-pressure-eviction/)
- [Pod Quality of Service Classes](https://kubernetes.io/docs/concepts/workloads/pods/pod-qos/)
- [GKE: Managed Service for Prometheus](https://cloud.google.com/stackdriver/docs/managed-prometheus)
- [GKE: kube state metrics を収集して表示する](https://cloud.google.com/kubernetes-engine/docs/how-to/kube-state-metrics)
- [GKE: cAdvisor / kubelet メトリクス](https://cloud.google.com/kubernetes-engine/docs/how-to/cadvisor-kubelet-metrics)
- [GKE: Plan node sizes](https://cloud.google.com/kubernetes-engine/docs/concepts/plan-node-sizes)
- [Kubernetes Metrics Reference](https://kubernetes.io/docs/reference/instrumentation/metrics/)
- [GKE system metrics（`status_condition` と `memory_type`）](https://cloud.google.com/monitoring/api/metrics_kubernetes)
- [GKE: 一覧に無い Prometheus メトリクスを収集する](https://cloud.google.com/kubernetes-engine/docs/how-to/collect-specific-prometheus-metrics)
- [Cloud Monitoring API v3: timeSeries.list](https://cloud.google.com/monitoring/api/ref_v3/rest/v3/projects.timeSeries/list)
- [google_container_cluster](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_cluster)
