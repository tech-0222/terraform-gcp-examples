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
04:26:48  besteffort
  The node was low on resource: memory. Threshold quantity: 100Mi, available: 12Ki.
  Container app was using 192Ki, request is 0, has larger consumption of memory.
```

ディスク逼迫のとき。

```text
04:33:47  hog
  The node was low on resource: ephemeral-storage. Threshold quantity: 2722654248,
  available: 2509916Ki.
04:34:05  diskfill
  ... Container fill was using 40Ki, request is 0, has larger consumption of ephemeral-storage.
```

メッセージに**しきい値・そのときの空き・そのコンテナの使用量と requests** が入っている。**QoS クラスは書かれていない。** 判断は requests との比較で行われる。

`requests` が 0 の BestEffort は、**192Ki 使っただけで「超過」になる。**

別の回では順序が変わった。1回目は `besteffort` → `hog`、2回目は `hog` のみ。**1回の観測で退避順を結論づけてはいけない。**

### 3. DiskPressure は約7分で再現できた

`emptyDir` に 20GB 書き込む。`emptyDir` は nodefs 上にあるので、書いた分だけ `nodefs.available` が減る。

```text
04:27:00  diskfill 投入
04:33:53  DiskPressure=True   （413秒）
```

**空きが戻っても `DiskPressure=True` は続く。** `evictionPressureTransitionPeriod` が 5分あるため。

### 4. kubelet のメトリクス

```console
$ kubectl get --raw "/api/v1/nodes/<NODE>/proxy/metrics" \
    | grep -E '^# TYPE kubelet_evictions |^kubelet_evictions'
# TYPE kubelet_evictions counter
kubelet_evictions{eviction_signal="memory.available"} 1

$ ... | grep -c '^kubelet_eviction_stats_age_seconds_count'
3
$ ... | grep -oP 'eviction_signal="\K[^"]+' | sort -u
allocatableMemory.available
containerfs.available
nodefs.available
```

**`kubelet_evictions_total` という名前では出ない。`_total` を外すと存在する。**

kubelet のソースでは `Subsystem: kubelet` / `Name: evictions` の CounterVec として[登録されている](https://github.com/kubernetes/kubernetes/blob/master/pkg/kubelet/metrics/metrics.go)。`_total` が付くのは OpenMetrics 形式のときで、`/metrics` の素の出力には付かない。

最初は `_total` 付きで数えて0件になり、「存在しない」と結論づけた。**出力は合っていて、照合する名前が間違っていた。** 上の出力はローカルの minikube（kubelet v1.37.0）で取り直したもので、**GKE 上に `kubelet_evictions` があったかは確かめられていない**（同じ誤った名前で数えたあと destroy した）。

ただし GMP には来ない。GKE の `KUBELET` は [curated set](https://cloud.google.com/kubernetes-engine/docs/how-to/cadvisor-kubelet-metrics) で、eviction 系を1つも含まないため。

### 5. Cloud Logging には残る

```console
$ gcloud logging read '<query>' --freshness=2h
  resource.type="k8s_pod" AND jsonPayload.reason="Evicted"        7 件
  resource.type="k8s_node" AND jsonPayload.reason=~"Evict|Pressure"  9 件
  resource.type="k8s_node" AND jsonPayload.MESSAGE=~"eviction"     93 件
  protoPayload.serviceName="container.googleapis.com"              24 件
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
| `kubelet_running_containers` | 3 | `kubelet_eviction_stats_age_seconds_count` | 0 |
| `kubelet_node_name` | 1 | `kube_pod_container_resource_requests` | 0 |
| `container_memory_working_set_bytes` | 76 | `kube_node_status_allocatable` | 0 |

**ジョブが `up=1` でも、メトリクスが全部来るわけではない。**

これは仕様どおりで、GKE のマネージド収集は[コンポーネントごとに出すメトリクスを公開している](https://cloud.google.com/kubernetes-engine/docs/how-to/kube-state-metrics)。今回 kube-state-metrics 系で有効にしたのは `POD` だけで、その一覧は4つで全部だった。

```text
kube_pod_container_status_ready
kube_pod_container_status_waiting_reason
kube_pod_status_phase
kube_pod_status_unschedulable
```

`kube_pod_status_reason` は入っていない。`kube_node_` で始まるメトリクスは**どのコンポーネントの一覧にも無い**。kubelet 側も [curated set](https://cloud.google.com/kubernetes-engine/docs/how-to/cadvisor-kubelet-metrics) で、`kubelet_running_pods` はあるが `kubelet_eviction_stats_age_seconds` は無い。上の実測と過不足なく一致する。

**`enable_components` を足しても取れない。** 残る `DAEMONSET` / `DEPLOYMENT` / `HPA` / `STATEFULSET` / `STORAGE` を全部有効にしても、この2つはどの一覧にも入っていない。

一覧に無いメトリクスが要るなら、kube-state-metrics を自分でデプロイして `PodMonitoring` で拾う。手元で kube-prometheus-stack を立てた環境では `kube_pod_status_reason{reason="Evicted"}` が取れた。**GMP のマネージド収集は、退避の監視には足りない。**

退避は phase で間接的に見える。

```promql
kube_pod_status_phase{namespace="evict-test",pod=~"hog|diskfill"} == 1
  pod=diskfill phase=Failed  1
  pod=hog      phase=Failed  1
```

ただし `phase=Failed` は退避以外でもなる。**理由まで知るには Cloud Logging が要る。**

### 7. GCP ネイティブのメトリクスは取れる

```console
kubernetes.io/node/memory/used_bytes
  memory_type=evictable      最新 389,881,856
  memory_type=non-evictable  最新 1,705,693,184
kubernetes.io/node/memory/allocatable_utilization
  component=pods             最新 0.076
kubernetes.io/node/ephemeral_storage/used_bytes
                             最新 7,929,176,064
```

**`evictable` / `non-evictable` に分かれている。** ノード逼迫の監視はこちらで組むのが筋になる。

### 8. `gcloud monitoring` に時系列のサブコマンドが無い

```console
$ gcloud monitoring time-series list ...
ERROR: (gcloud.monitoring) Invalid choice: 'time-series'.
Maybe you meant:
  gcloud monitoring dashboards list
  gcloud monitoring policies list
```

時系列を引くには Monitoring API v3 を直接叩く。`scripts/collect.sh` はそうしている。

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
- [Cloud Monitoring API v3: timeSeries.list](https://cloud.google.com/monitoring/api/ref_v3/rest/v3/projects.timeSeries/list)
- [google_container_cluster](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_cluster)
