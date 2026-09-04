# 22. ノードプールのSURGEアップグレードと、Blue/Greenとの比較

ノードプールのアップグレード戦略は2つある。SURGE（既定）はノードを少しずつ入れ替える。BLUE_GREENは新しいノード群を丸ごと作ってから移す。

`21-gke-blue-green-node-pool-upgrade`でBlue/Greenを測った。この例では**同じ条件でSURGEを測り、直接比べる**。ノード数もワークロードも計測方法も21と同一で、違うのは`upgrade_settings`だけにしてある。

あわせて、SURGEの2つの設定も比べる。

- `max_surge = 1` / `max_unavailable = 0` — 先にノードを足してから排出する
- `max_surge = 0` / `max_unavailable = 1` — 追加ノードなしで排出する

## SURGEの設定

```hcl
upgrade_settings {
  strategy        = "SURGE"
  max_surge       = var.max_surge        # 通常サイズを超えて足せるノード数
  max_unavailable = var.max_unavailable  # 同時に落としてよいノード数
}
```

`blue_green_settings`はBLUE_GREEN専用で、SURGEとは併用できない。どちらか一方が0でも動くが、**両方0にはできない**（進めなくなる）。

## アップグレード先を2段用意する

`max_surge`の設定を変えて2回測るため、コントロールプレーンを**2段先**で作る。

| | バージョン |
|---|---|
| コントロールプレーン | `1.36.2-gke.2064000` |
| ノードプール（初期） | `1.35.7-gke.1027000` |
| 実行A の上げ先 | `1.35.7-gke.1150000` |
| 実行B の上げ先 | `1.36.2-gke.2064000` |

これでコントロールプレーンを途中で上げ直さずに済む。バージョンはチャンネルから外れていくので、applyの前に確認する。

```bash
gcloud container get-server-config --zone=asia-northeast1-a --format="json(channels)"
```

## 前提

- Terraform 1.10以上、`hashicorp/google` 7.x
- `gcloud`認証済み、対象プロジェクトで課金が有効
- 有効化するAPI: `compute.googleapis.com`、`container.googleapis.com`、`cloudkms.googleapis.com`

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
GKE 1.35.7-gke.1027000 → 1.35.7-gke.1150000 → 1.36.2-gke.2064000（REGULARチャンネル）
ワークロード: nginx 2レプリカ + podAntiAffinity + PDB(minAvailable 1) + preStop
計測: 踏み台から内部LBへ毎秒1回
```

ワークロードと計測方法は`21`とまったく同じにしてある。

## 検証結果

### 1. 設定がGKEに反映されている

```console
$ gcloud container node-pools describe tf-adv-gke-surge-np --cluster=tf-adv-gke-surge \
    --zone=asia-northeast1-a --format="yaml(upgradeSettings)"
upgradeSettings:
  maxSurge: 1
  strategy: SURGE
```

`maxUnavailable: 0` は既定値のため出力に現れない。

### 2. 実行A: max_surge = 1 / max_unavailable = 0

```console
$ gcloud container clusters upgrade tf-adv-gke-surge --node-pool=tf-adv-gke-surge-np \
    --cluster-version=1.35.7-gke.1150000 --zone=asia-northeast1-a --async
```

ノード数の推移に`max_surge = 1`の動きがそのまま出る。

```console
=== 21:16:02 nodes=2 ===
=== 21:16:18 nodes=3 ===   ← 先に1台足す
   ...
=== 21:18:13 nodes=2 ===   ← 旧ノードを1台落とす
=== 21:18:45 nodes=3 ===   ← また1台足す
   ...
=== 21:21:12 nodes=2 ===   ← 完了
MAX_NODES=3
```

**先に足してから落とす**ので、処理中も稼働ノードが2台を下回らない。

```console
$ tr ' ' '\n' < /tmp/runA-probe.txt | grep -v '^$' | sort | uniq -c
    359 200

$ gcloud container operations list --zone=asia-northeast1-a \
    --filter="operationType=UPGRADE_NODES AND targetLink~tf-adv-gke-surge" \
    --format="table(status,startTime,endTime)"
STATUS  START_TIME                      END_TIME
DONE    2026-09-04T21:15:06.494755341Z  2026-09-04T21:21:02.860952638Z
```

**失敗0回、5分56秒。**

### 3. max_surge の変更はノードを作り直さない

```console
$ terraform apply
  # google_container_node_pool.primary will be updated in-place
          ~ max_surge       = 1 -> 0
          ~ max_unavailable = 0 -> 1
Apply complete! Resources: 0 added, 1 changed, 0 destroyed.
```

`upgrade_settings`はin-placeで変わる。次のアップグレードから新しい設定が使われる。

### 4. 実行B: max_surge = 0 / max_unavailable = 1

追加ノードなしで同じことをする。

```console
=== 21:22:41 nodes=2 ===
   ...
=== 21:27:01 nodes=1 ===   ← 増えないまま、1台に減る
=== 21:27:33 nodes=2 ===
MAX_NODES=2
```

```console
$ tr ' ' '\n' < /tmp/runB-probe.txt | grep -v '^$' | sort | uniq -c
     19 000
    236 200
```

**19秒の完全断。** 生の記録では`000`が連続して並ぶ。

```
200 200 ... 200 000 000 000 000 000 000 000 000 000 000 000 000 000 000 000 000 000 000 000 200 200 ...
```

所要時間は3分20秒（`21:22:35` → `21:25:55`）で、実行Aより速い。

### 5. 実行Bで断が出た理由

Pod側とLB側の両方に原因があった。

```console
$ kubectl get events --sort-by=.lastTimestamp | grep FailedScheduling
Warning  FailedScheduling  pod/nginx-cmek-668999dbd8-f4kls
  0/2 nodes are available: 1 node(s) didn't match pod anti-affinity rules,
  1 node(s) were unschedulable.
```

追加ノードがないので、1台をcordonすると退避したPodの行き先がない。もう1台には既にnginxがいて、`podAntiAffinity`が同居を拒む。レプリカが1個に減った状態のまま次のノードの番が来て、受け先がゼロになる。

内部LB側でも起きていた。

```console
Warning  EnterDegradedMode  service/nginx-cmek-ilb
  Entering degraded mode for NEG default/nginx-cmek-ilb-... due to sync err:
  endpoint information for attach operation is incorrect
Warning  AttachFailed       service/nginx-cmek-ilb
  Failed to Attach 1 network endpoint(s): googleapi: Error 400:
  Invalid value for field 'resource.instance': 'gke-tf-adv-gke-surge-...-ywfi'.
  Couldn't find instance with a specified name ...
```

ノードが作り直される間、NEGが存在しないインスタンスを参照して縮退した。

**`max_surge = 0`は「追加ノードが要らない」設定ではなく、「余力を持たずに入れ替える」設定**と読むのが正しい。ワークロードがノード数に対して余裕を持っていないと、そのまま断になる。

### 6. アップグレード後の terraform plan

```console
$ terraform plan
No changes. Your infrastructure matches the configuration.
```

`lifecycle.ignore_changes = [version]`が効いている。`21`ではコントロールプレーンも`gcloud`で上げたため読み取り専用の`master_version`に差分が出たが、この例では最初から上げ先のバージョンで作ってあるので差分が出ない。

## 3方式の比較

同じクラスタ構成・同じワークロード・同じ計測方法で測った結果。

| 観点 | Blue/Green | SURGE `max_surge=1` | SURGE `max_surge=0` |
|---|---|---|---|
| **断** | 0回 | 0回 | **19秒の完全断** |
| **所要時間** | 17分3秒 | 5分56秒 | **3分20秒** |
| 最大ノード数（2ノード時） | **4（倍）** | 3（+1） | 2（増えない） |
| 追加ノードのコスト | 倍のノード × 17分 | +1ノード × 6分 | **なし** |
| Pod IPの一時消費 | 倍 | +1ノード分 | なし |
| vCPUクォータの一時増 | 倍 | +1ノード分 | なし |
| **ロールバック** | **soak期間中は可能** | 不可 | 不可 |
| 切り戻しの猶予 | `node_pool_soak_duration` | なし | なし |
| 途中で気付く機会 | バッチ間に待機あり | 逐次 | 逐次 |
| 手順の複雑さ | cancel → rollback が要る | 単純 | 単純 |
| 向く場面 | 戻せることが最優先 | **既定として妥当** | 検証環境・コスト最優先 |

### 読み取れること

**断と時間だけ見るとSURGEが有利。** Blue/Greenは3倍近く遅く、ノードも倍要る。それでいて断は`max_surge=1`と同じ0回だった。

**Blue/Greenの価値は「上げたあとに問題が分かったとき」にある。** SURGEは置き換えたノードが残らないので、戻すにはもう一度アップグレード（ダウングレードは不可）するしかない。Blue/Greenは`node_pool_soak_duration`の間なら旧ノードが生きていて、`21`の実測では3分10秒で戻せた。

**`max_surge = 0`は安易に選ばない。** 速くて無料だが、ワークロードにノードの余裕がないと断が出る。今回は2ノードに2レプリカ+ハードなアンチアフィニティという、余裕がまったくない構成だった。

言い換えると、この3つは**「速さ・コスト・戻せること」のどれを取るか**の選択になる。断そのものは、ノード数とワークロードの配置に余裕があるかで決まる部分が大きい。

## 後片付け

内部LBはKubernetes側で作ったものなので、先に消す。残しておくと転送ルールがVPCに残る。

```console
$ kubectl delete -f k8s/03-nginx-ilb.yaml
service "nginx-cmek-ilb" deleted from default namespace

$ terraform destroy
Destroy complete! Resources: 27 destroyed.
```

Cloud KMSのキーリングと鍵は削除できず、鍵バージョンは破棄がスケジュールされる。再実行するときは`kms_key_ring_name` / `kms_crypto_key_name`に別名を指定する。

## 参考資料

- [Google Cloud: Node pool upgrade strategies](https://cloud.google.com/kubernetes-engine/docs/concepts/node-pool-upgrade-strategies)
- [Google Cloud: Configure surge upgrades](https://cloud.google.com/kubernetes-engine/docs/how-to/node-pool-upgrade-strategies)
- [Kubernetes: Specifying a Disruption Budget](https://kubernetes.io/docs/tasks/run-application/configure-pdb/)
- [Terraform Registry: google_container_node_pool](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_node_pool)
