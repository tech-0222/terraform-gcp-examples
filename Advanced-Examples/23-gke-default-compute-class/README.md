# 23. default_compute_class_enabled は何をするスイッチか

`cluster_autoscaling.default_compute_class_enabled` は、名前が3層で違う。

| 層 | 名前 |
|---|---|
| Terraform | `cluster_autoscaling.default_compute_class_enabled` |
| REST API | `clusterAutoscaling.defaultComputeClassConfig.enabled` |
| コンソール | Autopilot compute class compatibility |

Terraform Registryの説明はこうなっている。

> If enabled, cluster autoscaler will use Compute Class with name `default` for all the workloads, if not overriden.

ところが**その`default`というComputeClassはGKEが用意しない。** 有効にしただけでは何も起きない。

この例では、スイッチを切り替えながらノード自動プロビジョニング（NAP）にノードを作らせて、何が変わるかを実測する。

## 構成

| リソース | 用途 |
|---|---|
| VPC + サブネット2つ + Cloud NAT | GKEノードと踏み台。外部IPなし |
| 踏み台VM | プライベートエンドポイントのGKEへ到達する唯一の経路 |
| GKEクラスタ（Standard、ゾーナル、プライベート） | `cluster_autoscaling`でNAPを有効化 |
| 固定ノードプール（1ノード） | システムPod用。ここに収まらないものがNAPを起動する |

**`enable_autopilot`とは別物。** あちらはクラスタ全体をAutopilotにする。こちらはStandardのまま、オートスケーラのマシン選択だけを変える。

## 設定

```hcl
cluster_autoscaling {
  enabled = true                                              # NAP

  default_compute_class_enabled = var.default_compute_class_enabled

  resource_limits {
    resource_type = "cpu"
    maximum       = var.nap_max_cpu
  }
  resource_limits {
    resource_type = "memory"
    maximum       = var.nap_max_memory_gb
  }

  auto_provisioning_defaults {
    service_account = google_service_account.gke_node.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]
    disk_size       = 30
    disk_type       = "pd-balanced"
  }
}
```

NAPを有効にしないと、オートスケーラはノードプールを作れない。スイッチに作用対象がなくなる。

## 前提

- Terraform 1.10以上、`hashicorp/google` 7.x
- `gcloud`認証済み、対象プロジェクトで課金が有効
- 有効化するAPI: `compute.googleapis.com`、`container.googleapis.com`

## 実行

```bash
cp terraform.tfvars.example terraform.tfvars
# project_id と iap_member を自分の値に書き換える
terraform init
terraform apply
```

## 検証環境

```
Terraform v1.14.5
provider registry.terraform.io/hashicorp/google v7.46.0
GKE 1.35.7-gke.1027000（REGULARチャンネル）
```

## 検証結果

### 1. 確認コマンドは `autoscaling`。`clusterAutoscaling` ではない

REST APIのフィールド名は`clusterAutoscaling`だが、`gcloud container clusters describe`の出力では`autoscaling`になる。

```console
$ gcloud container clusters describe tf-adv-gke-dcc --zone=asia-northeast1-a \
    --format="yaml(clusterAutoscaling)"

  null
```

```console
$ gcloud container clusters describe tf-adv-gke-dcc --zone=asia-northeast1-a \
    --format=json | jq '.autoscaling.defaultComputeClassConfig'
{}
```

### 2. `false` は「空オブジェクト」として現れる

```console
$ gcloud container clusters describe tf-adv-gke-dcc --zone=asia-northeast1-a \
    --format=json | jq '.autoscaling'
{
  "autoprovisioningNodePoolDefaults": { ... },
  "autoscalingProfile": "BALANCED",
  "defaultComputeClassConfig": {},
  "enableNodeAutoprovisioning": true,
  "resourceLimits": [
    { "maximum": "12", "resourceType": "cpu" },
    { "maximum": "48", "resourceType": "memory" }
  ]
}
```

`enabled: false` とは出ない。**空オブジェクトかどうかで判断する。**

### 3. 切り替えはクラスタ再作成を伴わない

```console
$ terraform plan
  # google_container_cluster.primary will be updated in-place
          ~ default_compute_class_enabled = false -> true
Plan: 0 to add, 1 to change, 0 to destroy.

$ terraform apply
Apply complete! Resources: 0 added, 1 changed, 0 destroyed.
```

```console
$ gcloud container clusters describe ... --format=json | jq '.autoscaling.defaultComputeClassConfig'
{
  "enabled": true
}
```

有効時は`{"enabled": true}`になる。既存ノードやPodは影響を受けない。

### 4. ComputeClassはスイッチと無関係に存在する。ただし `default` はない

```console
$ kubectl get crd | grep computeclass
computeclasses.cloud.google.com                    2026-09-04T22:17:38Z

$ kubectl get computeclasses
NAME             AGE
autopilot        5m38s
autopilot-arm    5m38s
autopilot-spot   5m38s
```

スイッチが`false`でもCRDと`autopilot`系3つは存在する。**`default`という名前のものだけがない。**

スイッチを`true`にしても、`default`は生成されなかった。

```console
$ kubectl get computeclasses
NAME             AGE
autopilot        16m
autopilot-arm    16m
autopilot-spot   16m
```

### 5. `default` を自分で作ると効く

```yaml
apiVersion: cloud.google.com/v1
kind: ComputeClass
metadata:
  name: default
spec:
  priorities:
    - machineFamily: n2
  nodePoolAutoCreation:
    enabled: true
  whenUnsatisfiable: ScaleUpAnyway
```

作る前は、何も指定しないPodに対してオートスケーラが`e2-standard-2`を選んでいた。

```console
NAME                                                  TYPE            POOL
gke-tf-adv-gke-dcc-nap-e2-standard-2--943f1681-l4d6   e2-standard-2   nap-e2-standard-2-yg2nnsw8
```

`default`を作ったあと、同じ形のPodを投げると`n2-standard-2`になった。

```console
$ kubectl get pods -l app=burst2 -o wide
NAME                      READY   STATUS    NODE
burst2-85bdf8fbc5-z7qwh   1/1     Running   gke-tf-adv-gke-dcc-nap-n2-standard-2--7c4379cf-9mxh

NAME                                                  TYPE            POOL
gke-tf-adv-gke-dcc-nap-n2-standard-2--7c4379cf-9mxh   n2-standard-2   nap-n2-standard-2-gpgug1e5
```

Pod側は何も指定していない。`nodeSelector`も`ComputeClass`の指定もない。

### 6. スイッチを切ると無視される

`default`を`machineFamily: c3`に変え、スイッチを`false`に戻して、既存のどのノードにも収まらないPod（CPU 3500m / メモリ 6Gi）を投げた。

```console
$ kubectl get computeclass default -o jsonpath='{.spec.priorities}'
[{"machineFamily":"c3"}]

$ gcloud container clusters describe ... --format=json | jq '.autoscaling.defaultComputeClassConfig'
{}
```

```console
burst6 node: gke-tf-adv-gke-dcc-nap-e2-standard-4--6bbc1af1-j7r7
e2-standard-4
```

c3ではなく**e2-standard-4**の新しいノードプールが作られた。`default` ComputeClassは無視されている。

| スイッチ | `default` ComputeClass | オートスケーラが作ったノード |
|---|---|---|
| `true` | `machineFamily: n2` | **n2**-standard-2 |
| `false` | `machineFamily: c3` | **e2**-standard-4 |

スイッチが効いていることが確認できた。

### 7. スケールアップしない理由は describe に出ない

検証中、Podが`Pending`のまま動かないことがあった。`kubectl describe pod`はこれしか言わない。

```console
Warning  FailedScheduling  default-scheduler
  0/5 nodes are available: 1 Insufficient memory, 4 Insufficient cpu.
```

理由はオートスケーラのログにあった。

```console
$ gcloud logging read 'logName=~"cluster-autoscaler-visibility" AND resource.labels.cluster_name="tf-adv-gke-dcc"' \
    --limit=5 --freshness=2h --format=json
```

```json
{
  "noDecisionStatus": {
    "noScaleUp": {
      "unhandledPodGroups": [{
        "napFailureReasons": [{
          "messageId": "no.scale.up.nap.pod.zonal.resources.exceeded",
          "parameters": ["asia-northeast1-a"]
        }],
        "rejectedMigs": [{
          "mig": { "nodepool": "nap-e2-medium-go8qcpk2" },
          "reason": {
            "messageId": "no.scale.up.mig.failing.predicate",
            "parameters": ["NodeResourcesFit", "Insufficient cpu", "Insufficient memory"]
          }
        }]
      }]
    }
  }
}
```

`resource_limits`のCPU上限（12）に当たっていた。**`describe`はスケジューラの言い分しか見せない。** オートスケーラが何を検討して何を却下したかは、このログにしかない。

スケールアップした場合の判断も残る。

```console
  2026-09-04T23:18:54  nap-e2-standard-4-14bu1tk2  <- ['burst5-...']
  2026-09-04T22:46:25  nap-n2-standard-2-gpgug1e5  <- ['burst3-...']
  2026-09-04T22:24:01  nap-e2-standard-2-yg2nnsw8  <- ['burst-...']
```

## Cloud Loggingに残るもの

| ログ | クエリ | 内容 |
|---|---|---|
| オートスケーラの判断 | `logName=~"cluster-autoscaler-visibility" AND resource.labels.cluster_name="CLUSTER"` | `decision.scaleUp`（作ったMIGと引き金のPod）、`noDecisionStatus.noScaleUp`（却下したMIGと理由）、`noScaleDown` |
| GKE監査ログ | `protoPayload.serviceName="container.googleapis.com"` | `UpdateCluster`。スイッチの切り替えもここに出る |

`no.scale.up.nap.pod.zonal.resources.exceeded` のようなNAP固有の失敗理由は、**`kubectl describe`にも`gcloud container operations`にも出ない。**

## 後片付け

```console
$ terraform destroy
Destroy complete! Resources: 22 destroyed.
```

NAPが作ったノードプールもクラスタごと消える。GKE・踏み台VM・Cloud NAT、それにNAPが作ったノードは利用中に料金が発生する。`resource_limits`を大きくしすぎない。

## まとめ

- **有効にしただけでは何も起きない。** `default`という名前のComputeClassを自分で作って初めて効く
- **`default`はGKEが用意しない。** `autopilot`系3つは最初から存在するが、`default`だけがない
- **`false`は空オブジェクトとして現れる。** `enabled: false`とは出ない
- **確認するフィールドは`autoscaling`。** REST APIの`clusterAutoscaling`という名前で`--format`を書くと`null`が返る
- 切り替えはin-place。クラスタ再作成は起きない
- **オートスケーラが動かない理由は`describe`に出ない。** `cluster-autoscaler-visibility`ログを見る

## 参考資料

- [Google Cloud: About custom compute classes](https://cloud.google.com/kubernetes-engine/docs/concepts/about-custom-compute-classes)
- [Google Cloud: Run workloads in Autopilot mode in Standard clusters](https://cloud.google.com/kubernetes-engine/docs/how-to/autopilot-classes-standard-clusters)
- [Google Cloud: Node auto-provisioning](https://cloud.google.com/kubernetes-engine/docs/how-to/node-auto-provisioning)
- [Google Cloud: Cluster autoscaler visibility logs](https://cloud.google.com/kubernetes-engine/docs/how-to/cluster-autoscaler-visibility)
- [Terraform Registry: google_container_cluster](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_cluster)
