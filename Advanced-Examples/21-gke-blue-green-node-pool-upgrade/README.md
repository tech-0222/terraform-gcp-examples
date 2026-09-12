# 21. ノードプールのBlue/Greenアップグレードとsoak期間

ノードプールのアップグレードには[3つの戦略がある](https://docs.cloud.google.com/kubernetes-engine/docs/concepts/node-pool-upgrade-strategies)。既定のSURGEは既存ノードを順番に置き換える。3つ目のAutoscaled blue-greenはPreviewで、ここでは扱わない。BLUE_GREENは新しいノード群（green）を丸ごと作ってからワークロードを移し、しばらく旧ノード群（blue）を残す。

この「しばらく残す」時間が`node_pool_soak_duration`で、**ロールバックできる猶予**にあたる。満了するとblueは削除され、後戻りできなくなる。

`20-gke-cmek-node-boot-disk-rotation`では`kubectl drain`で手動移行し、断をゼロにするまで構成を作り込んだ。この例では同じワークロードをGKEに移させて、次を実測する。

- 移行中にどれだけ止まるか（`20`と同じものさしで測る）
- soak期間中に本当にロールバックできるか
- ブートディスクのCMEK鍵バージョンはどうなるか

## 構成

| リソース | 用途 |
|---|---|
| VPC + サブネット2つ + Cloud NAT | GKEノードと踏み台。外部IPなし |
| 踏み台VM | プライベートエンドポイントのGKEへ到達する唯一の経路 |
| Cloud KMS キーリング + 鍵 | ノードのブートディスク暗号化（CMEK） |
| GKEクラスタ（Standard、ゾーナル、プライベート） | コントロールプレーンをノードプールより新しく作る |
| ノードプール（1つ） | `strategy = "BLUE_GREEN"`。blue/greenはこの1つの中で入れ替わる |

**ノードプールは1つのまま**なのがSURGEとの共通点で、`20`のようにプールを2つ用意する必要はない。

## Blue/Greenの設定

```hcl
upgrade_settings {
  strategy = "BLUE_GREEN"

  blue_green_settings {
    node_pool_soak_duration = "600s"   # ロールバックできる猶予。GKE既定は3600s

    standard_rollout_policy {
      batch_percentage    = 0.5        # 0〜1の割合。パーセントではない
      batch_soak_duration = "60s"
    }
  }
}
```

`max_surge` / `max_unavailable`はSURGE用で、BLUE_GREENとは併用できない。

## アップグレード先を用意する

ノードプールはコントロールプレーンより新しくできない。そのため、この例は**コントロールプレーンを先に新しくして作る**。

```hcl
min_master_version = var.master_version      # 1.35.7-gke.1150000
```
```hcl
version = var.node_pool_version              # 1.35.7-gke.1027000

lifecycle {
  ignore_changes = [version]
}
```

アップグレードは`gcloud`で打つので、`ignore_changes`がないと次のapplyでバージョンが巻き戻る。

**バージョンはチャンネルから外れていく。** 開始バージョン 1.35.7-gke.1027000 はすでに提供が終わっている可能性が高い。applyの前に確認する。

```bash
gcloud container get-server-config --zone=asia-northeast1-a --format="json(channels)"
```

## 前提

- Terraform 1.10以上、`hashicorp/google` 7.x
- `gcloud`認証済み、対象プロジェクトで課金が有効
- 有効化するAPI: `compute.googleapis.com`、`container.googleapis.com`、`cloudkms.googleapis.com`（Terraformが有効化する）

Blue/Greenアップグレード中はノードが一時的に**倍**になる。PodのセカンダリレンジとvCPUの割り当てに余裕を持たせる。

## 実行

```bash
cp terraform.tfvars.example terraform.tfvars
# project_id と iap_member を自分の値に書き換える
terraform init
terraform apply
```

`terraform destroy`はCloud KMSのキーリングと鍵を消さず、鍵バージョンの破棄だけをスケジュールする（[削除機能そのものはGA済み](https://docs.cloud.google.com/kms/docs/release-notes)）。再実行するときは`kms_key_ring_name` / `kms_crypto_key_name`に別名を指定する。

## 検証環境

```
Terraform v1.14.5
provider registry.terraform.io/hashicorp/google v7.46.0
GKE 1.35.7-gke.1027000 → 1.35.7-gke.1150000（REGULARチャンネル）。ノードが到達したのはここまで。1.36.2-gke.2064000 はコントロールプレーンの `master_version` で、2回目の移行先は記録していない
```

## 検証結果

### 1. 設定がGKEに反映されている

```console
$ gcloud container node-pools describe tf-adv-gke-bg-np --cluster=tf-adv-gke-bg \
    --zone=asia-northeast1-a --format="yaml(upgradeSettings)"
upgradeSettings:
  blueGreenSettings:
    nodePoolSoakDuration: 600s
    standardRolloutPolicy:
      batchPercentage: 0.5
      batchSoakDuration: 60s
  strategy: BLUE_GREEN
```

`batchPercentage`が`0.5`であって`50`ではない点に注意する。Terraform側も0〜1の割合で書く。

### 2. 測り方: 踏み台から内部LB経由で測る

Blue/Greenアップグレードはblueノードを**全て**入れ替える。クラスタ内に置いたプローブPodは、計測対象のワークロードと一緒に退避されてしまう。

そこで内部LB（`k8s/03-nginx-ilb.yaml`）を立て、踏み台から毎秒1回リクエストする。アップグレード全体を通して観測でき、外から見た可用性という点でも実態に近い。

```console
$ kubectl get svc nginx-cmek-ilb
NAME             TYPE           EXTERNAL-IP   PORT(S)
nginx-cmek-ilb   LoadBalancer   10.40.0.5     80:31234/TCP
```

### 3. Blue/Greenの共存

アップグレードを開始する。

```console
$ gcloud container clusters upgrade tf-adv-gke-bg --node-pool=tf-adv-gke-bg-np \
    --cluster-version=1.35.7-gke.1150000 --zone=asia-northeast1-a --async
```

2分ほどでgreenが立ち上がり、同一ノードプールの中に新旧が並ぶ。

```console
$ kubectl get nodes -o custom-columns=NAME:.metadata.name,VERSION:.status.nodeInfo.kubeletVersion,SCHED:.spec.unschedulable
NAME                                               VERSION               SCHED
gke-tf-adv-gke-bg-tf-adv-gke-bg-np-41052e12-0zr5   v1.35.7-gke.1150000   <none>
gke-tf-adv-gke-bg-tf-adv-gke-bg-np-eabbc370-m475   v1.35.7-gke.1027000   <none>
gke-tf-adv-gke-bg-tf-adv-gke-bg-np-eabbc370-vhjl   v1.35.7-gke.1027000   <none>
```

名前の中ほどにあるハッシュ（`41052e12` / `eabbc370`）がインスタンステンプレートの世代で、これがblue/greenの見分けになる。

その後blueがcordonされ、Podが移り、blueが消える。

```console
=== 11:57:42 ===
gke-...-41052e12-0zr5   v1.35.7-gke.1150000   <none>
gke-...-41052e12-z46k   v1.35.7-gke.1150000   <none>
gke-...-eabbc370-m475   v1.35.7-gke.1027000   true     ← cordon済み
gke-...-eabbc370-vhjl   v1.35.7-gke.1027000   true

=== 11:58:44 ===
gke-...-41052e12-0zr5   v1.35.7-gke.1150000   <none>
gke-...-41052e12-z46k   v1.35.7-gke.1150000   <none>
```

### 4. 進行段階は UPGRADE_STAGE で読める

`kubectl get nodes`だけでは、いまblueをdrainしているのか、soak期間に入ったのかが分からない。operationのメトリクスに出る。

```console
$ gcloud container operations describe OPERATION_ID --zone=asia-northeast1-a \
    --format="value(progress.metrics[0].stringValue,status)"
12:14:29 DRAINING_BLUE_POOL	RUNNING
12:15:13 DRAINING_BLUE_POOL	RUNNING
   ...
12:18:07 DRAINING_BLUE_POOL	RUNNING
12:18:28 NODE_POOL_SOAKING	RUNNING
```

`CORDONING_BLUE_POOL` → `DRAINING_BLUE_POOL` → `NODE_POOL_SOAKING` と進む。ロールバックを試すならこれを見る。

### 5. 移行中の断: 失敗0回

アップグレードの全期間（17分3秒）にわたって毎秒1回、内部LBへリクエストした。

```console
$ tr ' ' '\n' < /tmp/bg-probe.txt | grep -v '^$' | sort | uniq -c
    900 200

$ gcloud container operations list --zone=asia-northeast1-a \
    --filter="operationType=UPGRADE_NODES" --format="table(status,startTime,endTime)"
STATUS  START_TIME                      END_TIME
DONE    2026-09-04T11:41:41.337259145Z  2026-09-04T11:58:44.228254785Z
```

**900回すべて200。** ワークロード側の設定は`20`と同じ（2レプリカ + `podAntiAffinity` + PDB + `preStop`）で、Blue/Greenのために足したものはない。

`20`との比較。

| 移行方法 | 断 | 所要時間 |
|---|---|---|
| 手動drain（replicas 1、Service名） | 21回連続で失敗 | 約2分 |
| 手動drain（2レプリカ + PDB、ClusterIP） | 30回中5回失敗 | 約2分 |
| 手動drain（+ `preStop`） | 0回 | 約2分 |
| **Blue/Green（踏み台→内部LB）** | **900回中0回** | **17分3秒** |

計測先が3種類あり計測区間も揃っていないので、この表から比は出せない。

止まらないが、**この設定では桁違いに遅い**。17分3秒のうち`node_pool_soak_duration`の600秒とバッチ待機が占める。[`complete-upgrade`でsoakを途中終了できる](https://docs.cloud.google.com/kubernetes-engine/docs/how-to/upgrading-a-cluster)ので、所要時間は固定ではない。

### 6. ロールバックは「キャンセルしてから」

実行中のoperationがあるあいだに`rollback`を打つと拒否される。試したのは`DRAINING_BLUE_POOL`と`NODE_POOL_SOAKING`の2段階。

```console
$ gcloud container node-pools rollback tf-adv-gke-bg-np --cluster=tf-adv-gke-bg \
    --zone=asia-northeast1-a
ERROR: (gcloud.container.node-pools.rollback) ResponseError: code=400,
message=Cluster is running incompatible operation operation-1788523948727-...
```

`DRAINING_BLUE_POOL`でも`NODE_POOL_SOAKING`でも同じ結果になる。ヘルプに理由が書いてある。

```console
$ gcloud container node-pools rollback --help
DESCRIPTION
    Rollback a node-pool upgrade.

    Rollback is a method used after a canceled or failed node-pool upgrade. It
    makes a best-effort attempt to revert the pool back to its original state.
```

**キャンセルが先**で、`rollback`はその後始末をするコマンドだった。

```console
$ gcloud container operations cancel OPERATION_ID --zone=asia-northeast1-a
status: ABORTING

$ gcloud container operations describe OPERATION_ID --zone=asia-northeast1-a \
    --format="yaml(status,statusMessage,progress)"
progress:
  metrics:
  - name: UPGRADE_STAGE
    stringValue: NODE_POOL_SOAKING
status: DONE
statusMessage: 'Operation was aborted: operation was aborted.'
```

キャンセルしてもblueは残っている。ここで`rollback`を打つ。

```console
$ gcloud container node-pools rollback tf-adv-gke-bg-np --cluster=tf-adv-gke-bg \
    --zone=asia-northeast1-a --respect-pdb=true
Updated [https://container.googleapis.com/v1/projects/PROJECT_ID/zones/asia-northeast1-a/clusters/tf-adv-gke-bg/nodePools/tf-adv-gke-bg-np].
```

3分10秒で完了した。

```console
$ gcloud container node-pools describe tf-adv-gke-bg-np --cluster=tf-adv-gke-bg \
    --zone=asia-northeast1-a --format="value(version)"
1.35.7-gke.1150000

$ kubectl get nodes -o custom-columns=NAME:.metadata.name,VERSION:.status.nodeInfo.kubeletVersion,READY:'.status.conditions[?(@.type=="Ready")].status',SCHED:.spec.unschedulable
NAME                                               VERSION               READY   SCHED
gke-tf-adv-gke-bg-tf-adv-gke-bg-np-41052e12-0zr5   v1.35.7-gke.1150000   True    <none>
gke-tf-adv-gke-bg-tf-adv-gke-bg-np-41052e12-z46k   v1.35.7-gke.1150000   True    <none>
```

greenは削除され、blueはuncordonされてPodも戻った。上のタイムラインの 12:20:01 から 12:23:11 にあたる。

タイムライン。

```
12:12:26  アップグレード開始
12:13:43  blue が cordon され、green が Ready
12:14:03  rollback         → 拒否（DRAINING_BLUE_POOL）
12:18:28  NODE_POOL_SOAKING に到達
12:18:41  rollback         → 拒否（incompatible operation）
12:19:13  operations cancel → ABORTING
12:19:45  DONE / "Operation was aborted"
12:20:01  rollback         → 成功
12:23:11  完了
```

この一連（アップグレード → キャンセル → ロールバック）の全期間でも、サンプルに失敗は出なかった。観測できるのはサンプルの時点だけで、無停止の保証ではない。

```console
$ tr ' ' '\n' < /tmp/rb-probe.txt | grep -v '^$' | sort | uniq -c
    631 200
```

### 7. アップグレード後の terraform plan

```console
$ terraform plan
Note: Objects have changed outside of Terraform

  ~ master_version = "1.35.7-gke.1150000" -> "1.36.2-gke.2064000"

Changes to Outputs:
  ~ master_version = "1.35.7-gke.1150000" -> "1.36.2-gke.2064000"
```

ノードプールには差分が出ない。`lifecycle.ignore_changes = [version]`が効いている。`master_version`は読み取り専用の属性で、出力値が変わるだけでインフラは変更されない。

`min_master_version`は「これ以上」を指す下限で、作成時にしか効かない属性ではない。[provider は現在のバージョンと比べ、指定値のほうが新しいときだけ更新する](https://github.com/hashicorp/terraform-provider-google/blob/main/google/services/container/resource_container_cluster.go)。差分が出なかったのは、`gcloud`で上げた結果が変数の値より新しいため。

### 8. ローテーション直後のアップグレードでは、旧鍵バージョンで作られた

アップグレードの直前に鍵をローテーションした。ところがgreenノードのブートディスクは**旧バージョン**だった。

```console
$ gcloud compute disks list --filter="name~gke-tf-adv-gke-bg" \
    --format="table(name,creationTimestamp,diskEncryptionKey.kmsKeyName.basename())"
NAME                                              CREATION_TIMESTAMP             KMS_KEY_NAME
gke-tf-adv-gke-bg-tf-adv-gke-bg-np-41052e12-0zr5  2026-09-04T04:41:54.435-07:00  1
gke-tf-adv-gke-bg-tf-adv-gke-bg-np-41052e12-z46k  2026-09-04T04:41:54.434-07:00  1
```

`20`では「新しく作られたノードは新しい鍵バージョンになる」ことを確認していたので、逆の結果になる。

原因はBlue/Greenではなかった。インスタンステンプレートが持っているのは鍵の**パスだけ**で、バージョンを含まない。

```console
$ gcloud compute instance-templates describe gke-tf-adv-gke-bg-tf-adv-gke-bg-np-41052e12 \
    --region=asia-northeast1 --format="value(properties.disks[0].diskEncryptionKey.kmsKeyName)"
projects/PROJECT_ID/locations/asia-northeast1/keyRings/tf-adv-gke-bg-ring/cryptoKeys/tf-adv-gke-bg-boot-disk
```

同じノードプールに、時間を空けてノードを1台足すと新しいバージョンになった。

```console
$ gcloud container clusters resize tf-adv-gke-bg --node-pool=tf-adv-gke-bg-np \
    --num-nodes=3 --zone=asia-northeast1-a

NAME                                              CREATION_TIMESTAMP             KMS_KEY_NAME
gke-tf-adv-gke-bg-tf-adv-gke-bg-np-41052e12-0zr5  2026-09-04T04:41:54.435-07:00  1
gke-tf-adv-gke-bg-tf-adv-gke-bg-np-41052e12-rv2c  2026-09-04T04:59:37.504-07:00  2
gke-tf-adv-gke-bg-tf-adv-gke-bg-np-41052e12-z46k  2026-09-04T04:41:54.434-07:00  1
```

| ノード作成 | ローテーションからの経過 | 鍵バージョン |
|---|---|---|
| 11:41:54 | +17秒 | 1 |
| 11:59:37 | +18分 | 2 |

同じプール、同じテンプレートで結果が割れた。primaryバージョンの切替が反映されるまでに時間がかかる。

> When you change the primary key version, the change typically becomes consistent within 1 minute. However, this change can take up to 3 hours to propagate in exceptional cases.
> （[Rotate a key](https://cloud.google.com/kms/docs/rotate-key)）

**鍵をローテーションしてすぐ移行作業を始めると、新しいノードが旧バージョンのまま作られる。** `20`の「移行完了は`terraform plan`ではなく`gcloud compute disks list`で確認する」がここでも効く。

## 後片付け

```console
$ terraform destroy
Destroy complete! Resources: 27 destroyed.
```

キーリングと鍵は残り、鍵バージョンは破棄がスケジュールされる。GKE・踏み台VM・Cloud NAT・内部LBは利用中に料金が発生する。

内部LBはKubernetes側で作ったものなので、`terraform destroy`の前に`kubectl delete -f k8s/03-nginx-ilb.yaml`で消しておくと転送ルールが残らない。

## 参考資料

- [Google Cloud: Node pool upgrade strategies](https://cloud.google.com/kubernetes-engine/docs/concepts/node-pool-upgrade-strategies)
- [Google Cloud: Use blue-green upgrades](https://cloud.google.com/kubernetes-engine/docs/how-to/node-pool-upgrade-strategies)
- [Google Cloud: Rotate a key](https://cloud.google.com/kms/docs/rotate-key)
- [Terraform Registry: google_container_node_pool](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_node_pool)
