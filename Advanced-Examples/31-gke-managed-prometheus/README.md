# 31-gke-managed-prometheus

GKE StandardでGoogle Cloud Managed Service for Prometheus（以下GMP）のManaged Collectionを使い、自前のExporter・alerting ruleをPodMonitoring・Rulesで置き換えたときに何が起きるかを**実際に動かして**確認する。

## 何を検証するか

| # | 検証すること |
|---|---|
| 1 | Managed CollectionはGKE Standardで既定有効か |
| 2 | 自前のExporterをPodMonitoringでscrapeできるか（port指定の落とし穴を含む） |
| 3 | `OperatorConfig`のtarget status機能でActive Targetsを確認できるか |
| 4 | 同じメトリクスがCloud MonitoringへPromQLで取得できるか |
| 5 | Rulesを適用すると何が自動デプロイされるか（rule-evaluator・Alertmanager） |
| 6 | alertingの一連の流れ（inactive→firing→Alertmanager→resolved）が動くか |
| 7 | 可視化2パターン（Cloud Monitoring Dashboard／Grafana継続利用）でそれぞれ何が要るか |
| 8 | managed kube-state-metricsパッケージで実際に取れるメトリクスは何か |
| 9 | `metricRelabeling`でメトリクスを止められるか |

## 構成

ノード1台のゾーンクラスタ。GKE Standard（Autopilotは不可、後述）。

```
e2-standard-2（Spot VM）
  node-exporter（DaemonSet、hostNetwork/hostPID/hostPath使用）
  grafana（Deployment、パターンB用）
  gmp-system: collector / gmp-operator / rule-evaluator / alertmanager
  gke-managed-cim: kube-state-metrics（managedパッケージ）
```

### なぜGKE Standardか

既存のNode Exporter DaemonSetは`hostNetwork: true` / `hostPID: true`を設定し、`hostPath: path: /`を`readOnly: true`でマウントしている。GKE Autopilotは`hostNetwork`・host namespaceを許可せず、`hostPath`も書き込みモードは全面禁止、read-onlyでも`/var/log/`配下のパスのみを許可する。`/`はこの対象外のため、Autopilotでは同じManifestを再利用できない。

## 前提条件

- Google Cloud CLI、Terraform、kubectl
- Billing が有効な検証用プロジェクト
- 実行元のグローバル **IPv4**（`curl -4 -s https://ifconfig.me`。IPv6を返す環境だとplanで落ちる）
- 検証時のバージョン：Terraform 1.14.3、google 7.46.1、GKE v1.35.8-gke.1225000

## 使い方

```bash
cp terraform.tfvars.example terraform.tfvars
terraform init && terraform apply
eval "$(terraform output -raw get_credentials)"

kubectl apply -f k8s/00-namespace.yaml
kubectl apply -f k8s/01-node-exporter.yaml
kubectl apply -f k8s/02-podmonitoring.yaml
kubectl apply -f k8s/03-rules.yaml

# target status機能の有効化。OperatorConfig/configは既定でgmp-public名前空間にあるため、
# gmp-systemへの新規作成は拒否される（後述）。既存のものをpatchする
kubectl patch operatorconfig config -n gmp-public --type merge \
  -p '{"features":{"targetStatus":{"enabled":true}}}'

# パターンB（Grafana継続利用）を試す場合
kubectl apply -f k8s/04-grafana-deployment.yaml
kubectl apply -f k8s/05-grafana-service.yaml

# GrafanaのService account tokenを作る（ポートフォワード後、ブラウザまたはAPIで）
kubectl port-forward -n monitoring svc/grafana 13000:3000 &
# http://localhost:13000 にGrafanaの既定クレデンシャルでログインし、
# Administration > Service accounts でtokenを作成するか、APIで作成する

# Prometheus data sourceを作成し、UIDを控える（APIの例。GRAFANA_AUTHはGrafanaの既定クレデンシャル）
GRAFANA_AUTH="admin:admin"
curl -u "${GRAFANA_AUTH}" -X POST http://localhost:13000/api/datasources \
  -H "Content-Type: application/json" \
  -d '{"name":"GMP","type":"prometheus","access":"proxy",
       "url":"https://monitoring.googleapis.com/v1/projects/PROJECT_ID/location/global/prometheus/",
       "jsonData":{"httpMethod":"GET"}}'

# data source syncerはGrafana service account token等の秘密情報を含むため、
# k8s/07-datasource-syncer.yaml.example から生成する（生成物はコミットしない）
sed "s|\$DATASOURCE_UIDS|<datasource-uid>|; \
     s|\$GRAFANA_API_ENDPOINT|http://grafana.monitoring.svc.cluster.local:3000|; \
     s|\$GRAFANA_API_TOKEN|<grafana-service-account-token>|; \
     s|\$PROJECT_ID|PROJECT_ID|" \
  k8s/07-datasource-syncer.yaml.example | kubectl apply -n monitoring -f -

terraform destroy
```

## 実測結果

### 1. Managed CollectionはGKE Standard 1.27以降で既定有効

クラスタ作成直後、何も導入していない時点で`gmp-system`に`collector`・`gmp-operator`が起動している。

```console
$ kubectl get pods -n gmp-system
NAME                            READY   STATUS    RESTARTS   AGE
collector-r7hz2                 2/2     Running   0          57s
gmp-operator-6b4f84fd77-xwcgd   1/1     Running   0          2m44s
```

Terraform側では`monitoring_config.managed_prometheus.enabled = true`を明示しているが、GKE Standard 1.27以降・Autopilot 1.25以降ではこの指定が無くても既定で有効（Standardは作成時に無効化できるが、Autopilotはできない）。

### 2. PodMonitoringの`port`を文字列で書くと名前として扱われる

最初に`port: "9100"`（文字列）と書いたところ、生成されたscrape設定は次のようになり、ターゲットが1つも見つからなかった。

```yaml
relabel_configs:
  - source_labels: [__meta_kubernetes_pod_container_port_name]
    regex: "9100"
    action: keep
```

このManifestのcontainerPortには`name`を付けていないため、`__meta_kubernetes_pod_container_port_name`は空文字列になり、`"9100"`という名前には一致しない。`port`フィールドは`x-kubernetes-int-or-string`で、YAMLでクォートすると文字列（名前として検索）、クォートしないと数値（ポート番号として検索）になる。`port: 9100`（数値）に直すと、`__address__`を`$1:9100`に書き換える正しい設定が生成され、scrapeできるようになった。

### 3. target statusの確認は`OperatorConfig`が`gmp-public`にある

最初に`gmp-system`名前空間へ`OperatorConfig/config`を新規作成しようとしたところ、次のエラーで拒否された。実機で確認すると、`OperatorConfig/config`は`gmp-public`名前空間に既定で存在していた。

```
ValidatingAdmissionPolicy 'operatorconfigs.monitoring.googleapis.com' with binding
'operatorconfigs.monitoring.googleapis.com' denied request: failed expression:
object.metadata.namespace == 'gmp-public'
```

既存の`gmp-public/config`を`kubectl patch`で更新すると、数分後に`PodMonitoring.status.endpointStatuses`へActive Targetsが反映された。

```console
$ kubectl patch operatorconfig config -n gmp-public --type merge \
    -p '{"features":{"targetStatus":{"enabled":true}}}'
```

```yaml
status:
  endpointStatuses:
  - name: PodMonitoring/monitoring/node-exporter/9100
    activeTargets: 1
    collectorsFraction: "1"
    sampleGroups:
    - sampleTargets:
      - health: up
```

設定変更がPodへ反映されるまで、`patch`実行から約4分かかった。ConfigMapの配布・設定の再読み込み・target statusの更新のどこで時間を要したかは切り分けていない。

### 4. 同じメトリクスがCloud MonitoringのPromQL APIで取得できる

```console
$ curl -H "Authorization: Bearer $(gcloud auth print-access-token)" \
    "https://monitoring.googleapis.com/v1/projects/PROJECT_ID/location/global/prometheus/api/v1/query" \
    --data-urlencode 'query=up{job="node-exporter"}'
{"status":"success","data":{"resultType":"vector","result":[{"metric":{
  "__name__":"up","cluster":"tf-adv-managed-prometheus","instance":"...:9100",
  "job":"node-exporter","location":"asia-northeast1-a","namespace":"monitoring",
  "pod":"node-exporter-...","project_id":"...","top_level_controller_name":"node-exporter",
  "top_level_controller_type":"DaemonSet"},"value":[...,"1"]}]}}
```

`project_id`・`location`・`cluster`はOperatorConfigのexternalLabelsとして全ジョブに付与される。`namespace`・`pod`・`top_level_controller_name`・`top_level_controller_type`はPodMonitoringの既定の`targetLabels.metadata`から付く。

### 5. `Rules`を適用すると`rule-evaluator`・`alertmanager`が初めて起動する

クラスタ作成直後は`collector`・`gmp-operator`の2つしかいない。`kubectl apply -f k8s/03-rules.yaml`を実行した直後に次の2つが増えた。

```console
$ kubectl get pods -n gmp-system
alertmanager-0                   2/2   Running
rule-evaluator-...                2/2   Running
```

### 6. alertingの一連の流れ

Node Exporter DaemonSetへ一時的に存在しないnodeSelectorを付けてPodを消し、`up==0`を45秒超続けた。

```text
inactive → firing（45秒後）→ Alertmanagerへ到達（receiver: noop）→ Pod復旧 → resolved
```

Alertmanagerの既定ルートは`noop`で、通知先を設定しない限りどこにも送られない（本記事の対象外）。firingしたアラートの`generatorURL`は、該当PromQLを埋め込んだCloud Monitoring Metrics Explorerへ直接リンクしていた。

### 7. 可視化2パターン

**パターンA（Cloud Monitoring Dashboard）**: 第1回で使ったPromQL（CPU・メモリ・ディスク使用率）はいずれも変更なしでCloud MonitoringのPromQL APIから取得できた。ディスク使用率のクエリは`mountpoint="/var"`を指定しているが、GKEのContainer-Optimized OSにも`/var`という独立したマウントポイントが存在し（`device=/dev/sda1, fstype=ext4`）、そのまま動いた。

**パターンB（Grafana継続利用）**: `data source syncer`はクエリ経路には入らない。実際のPromQLクエリはGrafanaから`https://monitoring.googleapis.com/v1/projects/PROJECT_ID/location/global/prometheus/`へ直接送られる。syncerは、GrafanaのPrometheus data sourceにこのURLとOAuth2トークンを書き込む・更新するだけのCronJob。このクラスタではWorkload Identity Federationを有効にしていないが、syncer PodはTerraformで作成しノードプールに割り当てた専用のサービスアカウント（`roles/monitoring.viewer`付き。GCPが自動生成する既定のCompute Engineサービスアカウントとは別物）で認証でき、問題なく動いた。

第1回のGrafana Dashboard JSONは、エクスポート時のテンプレート変数`${DS_PROMETHEUS}`をGMPのdata source UIDに置き換えるだけでimportできた。3つのPanel（CPU・メモリ・ディスク使用率）が参照しているPromQLは、data source経由の問い合わせで同じ値が返ることを確認した（ブラウザ上でのPanel描画は未確認）。

### 8. managed kube-state-metricsは4メトリクスだけ

`gke-managed-cim`namespaceの`kube-state-metrics-0`へport-forwardして`/metrics`を直接確認すると、公開されているのは次の4つだけだった。

```console
$ curl -s http://localhost:8080/metrics | grep "^# HELP"
# HELP kube_pod_container_status_ready [STABLE] ...
# HELP kube_pod_container_status_waiting_reason [STABLE] ...
# HELP kube_pod_status_phase [STABLE] ...
# HELP kube_pod_status_unschedulable [STABLE] ...
```

`kube_pod_info`・`kube_node_info`・`kube_deployment_status_replicas`などは無い。これらが要る場合は自前でkube-state-metricsを入れ、PodMonitoringで拾う必要がある（その場合はnamespaceが同じ`gke-managed-.*`パターンに一致しないよう注意する。managed側のPodMonitoringには`metricRelabeling`で`namespace=~"gke-managed-.*"`をdropする設定が既定で入っている）。

### 9. `metricRelabeling`でメトリクスを止められる

`node_textfile_scrape_error`に対して`action: drop`を追加し、適用時刻（07:33:26 UTC）を記録した。約4分後の設定反映後に1回確認したところ、このメトリクスのsample timestampは07:33台で止まっており、同時刻の他のメトリクス（`up`）は更新が続いていた。その後も継続して停止したままかは追跡していない。

## 削除方法

```bash
terraform destroy
```

**GKEは最もコストが高い。検証が終わったら速やかに削除する。** 過去に取り込まれた時系列データはCloud Monitoringの保持期間（24か月。先頭1週間は元粒度、以降1分粒度、最終的に10分粒度へdownsample）中は残る。収集を止めても既存データは削除されない。

## 注意 / 費用

- ノード1台（e2-standard-2、既定でSpot）+ GKEのクラスタ管理費（$0.10/時）。課金アカウントあたり月$74.40の無料枠はゾーナル/Autopilotクラスタ1つ分の管理費に相当し、他に同時稼働させていなければこの枠で相殺される
- GMP自体の課金はサンプル取り込み数とMonitoring API readに基づく。ストレージ・保持は無料
- `auto_repair`・`auto_upgrade`は有効（この検証はノード入れ替えに影響されない）
- data source syncerの`--grafana-api-token`にはGrafana service account tokenが入る。生成したManifestはコミットしない（`.gitignore`対象）

## 参考

- [GKE Autopilotのセキュリティ制約](https://cloud.google.com/kubernetes-engine/docs/concepts/autopilot-security)
- [Google Cloud Managed Service for Prometheus](https://cloud.google.com/stackdriver/docs/managed-prometheus)
- [Get started with managed collection](https://cloud.google.com/stackdriver/docs/managed-prometheus/setup-managed)
- [Managed rule evaluation and alerting](https://cloud.google.com/stackdriver/docs/managed-prometheus/rules-managed)
- [Troubleshooting Managed Service for Prometheus](https://cloud.google.com/stackdriver/docs/managed-prometheus/troubleshooting)
- [Query using Grafana](https://cloud.google.com/stackdriver/docs/managed-prometheus/query)
- [Collect and view kube state metrics](https://cloud.google.com/kubernetes-engine/docs/how-to/kube-state-metrics)
- [Cost controls and attribution](https://cloud.google.com/stackdriver/docs/managed-prometheus/cost-controls)
- [PromQL for Cloud Monitoring metrics](https://cloud.google.com/monitoring/promql)
- [google_container_cluster](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_cluster)
