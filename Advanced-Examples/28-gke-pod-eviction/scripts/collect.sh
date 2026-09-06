#!/usr/bin/env bash
# 退避の観測を4系統で採取する。
#
#   1. kubectl / kubelet   実際に何が起きたか
#   2. gcloud container    サービス側から見た状態
#   3. gcloud logging      ログに何が残るか（0件も結果）
#   4. gcloud monitoring   メトリクスが取れるか
#
# クラスタを destroy する前に4つとも取り終えること。
set -uo pipefail

PROJECT="${PROJECT:-$(gcloud config get-value project 2>/dev/null)}"
ZONE="${ZONE:-asia-northeast1-a}"
CLUSTER="${CLUSTER:-tf-adv-evict}"
NS="${NS:-evict-test}"
NODE="$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"

hr() { printf '\n===== %s =====\n' "$1"; }

hr "1-a. kubelet: 退避のしきい値（configz）"
kubectl get --raw "/api/v1/nodes/${NODE}/proxy/configz" 2>/dev/null | python3 -c '
import json,sys
c=json.load(sys.stdin)["kubeletconfig"]
for k in ("evictionHard","evictionSoft","evictionSoftGracePeriod",
          "evictionPressureTransitionPeriod","evictionMinimumReclaim",
          "evictionMaxPodGracePeriod","kubeReserved","systemReserved"):
    if c.get(k) is not None: print(f"  {k}: {c[k]}")'

hr "1-b. kubelet: 判断に使っている実値（stats/summary）"
kubectl get --raw "/api/v1/nodes/${NODE}/proxy/stats/summary" 2>/dev/null | python3 -c '
import json,sys
n=json.load(sys.stdin)["node"]
m,fs=n["memory"],n["fs"]
av=m["availableBytes"]; ws=m["workingSetBytes"]
fa=fs["availableBytes"]; fc=fs["capacityBytes"]
print("  memory.available  {:>10,.0f} MiB".format(av/2**20))
print("  memory.workingSet {:>10,.0f} MiB".format(ws/2**20))
print("  nodefs.available  {:>10,.1f} GiB / {:.1f} GiB ({:.1f}%)".format(fa/2**30, fc/2**30, fa*100/fc))'

hr "1-c. kubelet: 退避に関するメトリクス（/metrics）"
RAW="$(kubectl get --raw "/api/v1/nodes/${NODE}/proxy/metrics" 2>/dev/null)"
echo "  kubelet_evictions_total       : $(grep -c '^kubelet_evictions_total' <<<"$RAW") 行"
echo "  kubelet_eviction_stats_age    : $(grep -c '^kubelet_eviction_stats_age_seconds_count' <<<"$RAW") 行"
echo "  eviction_signal のラベル値:"
grep -oP 'eviction_signal="\K[^"]+' <<<"$RAW" | sort -u | sed 's/^/    /'

hr "1-d. kubectl: Pod の状態と退避イベント"
kubectl -n "$NS" get pods -o custom-columns='NAME:.metadata.name,QOS:.status.qosClass,STATUS:.status.phase,REASON:.status.reason' --no-headers
echo
kubectl -n "$NS" get events --field-selector reason=Evicted -o json 2>/dev/null | python3 -c '
import json,sys
items=json.load(sys.stdin).get("items",[])
if not items: print("  （退避イベントなし）")
for e in sorted(items,key=lambda x:x.get("firstTimestamp") or ""):
    print("  {}  {}".format(e.get("firstTimestamp"), e["involvedObject"]["name"]))
    print("    " + e["message"].strip())'

hr "1-e. kubectl: ノードの条件"
kubectl get node "$NODE" -o jsonpath='{range .status.conditions[?(@.type=="MemoryPressure")]}  {.type}={.status} ({.reason}){"\n"}{end}{range .status.conditions[?(@.type=="DiskPressure")]}  {.type}={.status} ({.reason}){"\n"}{end}'

hr "2. gcloud container: サービス側から見た状態"
gcloud container clusters describe "$CLUSTER" --zone="$ZONE" \
  --format="value(status, currentMasterVersion, monitoringConfig.componentConfig.enableComponents, monitoringConfig.managedPrometheusConfig.enabled)" 2>&1
gcloud container node-pools list --cluster="$CLUSTER" --zone="$ZONE" \
  --format="table(name, config.machineType, initialNodeCount, status)" 2>&1

hr "3. gcloud logging: ログに残るもの（0件も結果）"
for Q in \
  'resource.type="k8s_pod" AND jsonPayload.reason="Evicted"' \
  'resource.type="k8s_node" AND jsonPayload.reason=~"Evict|Pressure"' \
  'resource.type="k8s_node" AND jsonPayload.MESSAGE=~"eviction"' \
  'protoPayload.serviceName="container.googleapis.com"' ; do
  N=$(gcloud logging read "$Q" --limit=100 --freshness=2h --format='value(timestamp)' 2>/dev/null | wc -l)
  printf '  %-62s %3s 件\n' "${Q:0:62}" "$N"
done
echo
echo "  --- 退避ログの中身（先頭2件）---"
gcloud logging read 'resource.type="k8s_pod" AND jsonPayload.reason="Evicted"' \
  --limit=2 --freshness=2h --format="value(timestamp, jsonPayload.message)" 2>/dev/null | cut -c1-150 | sed 's/^/  /'

hr "4-a. gcloud monitoring: GMP 経由で PromQL を引く"
for Q in \
  'kube_pod_status_reason{reason="Evicted"}' \
  'kube_node_status_condition{condition="MemoryPressure",status="true"}' \
  'kubelet_eviction_stats_age_seconds_count' \
  'kubelet_evictions_total' ; do
  echo "  --- $Q"
  gcloud monitoring time-series list \
    --filter="metric.type=starts_with(\"prometheus.googleapis.com/\")" \
    --format=none 2>/dev/null
  curl -s -H "Authorization: Bearer $(gcloud auth print-access-token 2>/dev/null)" \
    "https://monitoring.googleapis.com/v1/projects/${PROJECT}/location/global/prometheus/api/v1/query" \
    --data-urlencode "query=${Q}" 2>/dev/null | python3 -c '
import json,sys
try: d=json.load(sys.stdin)
except Exception: print("      （取得失敗）"); sys.exit()
r=d.get("data",{}).get("result",[])
if not r: print("      × データなし"); sys.exit()
for x in r[:5]:
    m=x["metric"]
    lbl=" ".join("{}={}".format(k,v) for k,v in m.items() if k in ("pod","condition","status","reason","eviction_signal","namespace"))
    print("      ○ {:<62} {:,.2f}".format(lbl[:62], float(x["value"][1])))'
done

hr "4-b. gcloud monitoring: GCP 固有のノードメトリクス"
for M in \
  "kubernetes.io/node/memory/allocatable_utilization" \
  "kubernetes.io/node/memory/used_bytes" \
  "kubernetes.io/node/ephemeral_storage/used_bytes" ; do
  N=$(gcloud monitoring time-series list \
        --filter="metric.type=\"${M}\"" \
        --format="value(points[0].value.doubleValue,points[0].value.int64Value)" 2>/dev/null | head -3 | wc -l)
  printf '  %-56s %s 系列\n' "$M" "$N"
done
