# 20. GKEノードのブートディスクCMEKと鍵ローテーション

Cloud KMSの鍵をローテーションしても、稼働中のノードのブートディスクは古い鍵バージョンのまま残る。新しい鍵バージョンに移すには、ノードを作り直すしかない。

この例では、ノードプールを入れ替える移行を`terraform apply`だけで3フェーズに分けて進め、各段階でディスクがどの鍵バージョンを参照しているかを実測する。あわせて次も確認する。

- ローテーション後に`terraform plan`が差分を検知するか
- ノードプールを作り直さなくても新しい鍵バージョンになるのか
- 移行中にどれだけ通信が途切れるか、どうすれば途切れないか
- 旧ノードを残したまま旧鍵バージョンを無効化すると何が起きるか

## 構成

| リソース | 用途 |
|---|---|
| VPC + サブネット2つ + Cloud NAT | GKEノードと踏み台。外部IPなし |
| 踏み台VM | プライベートエンドポイントのGKEへ到達する唯一の経路（IAP TCP forwarding） |
| Cloud KMS キーリング + 鍵 | ノードのブートディスク暗号化用（CMEK） |
| IAMバインディング2つ | Compute EngineとGKEのサービスエージェントに`cryptoKeyEncrypterDecrypter` |
| GKEクラスタ（Standard、ゾーナル、プライベート） | `remove_default_node_pool = true` |
| ノードプール v1 / v2 | `boot_disk_kms_key`に**同じ鍵**を指定。作成タイミングだけが違う |

## 3フェーズの進め方

| フェーズ | `keep_v1_node_pool` | `create_v2_node_pool` | 状態 |
|---|---|---|---|
| 1. 初期 | `true` | `false` | v1のみ。鍵はバージョン1がprimary |
| 2. ローテーション後 | `true` | `true` | v1 + v2 |
| 3. 移行完了 | `false` | `true` | v2のみ |

フェーズ1→2の間に`gcloud kms keys versions create --primary`で鍵をローテーションし、フェーズ2→3の間に`kubectl drain`でワークロードを移す。

## 前提

- Terraform 1.10以上、`hashicorp/google` 7.x
- `gcloud`認証済み、対象プロジェクトで課金が有効
- 有効化するAPI: `compute.googleapis.com`、`container.googleapis.com`、`cloudkms.googleapis.com`（Terraformが有効化する）

## 実行

```bash
cp terraform.tfvars.example terraform.tfvars
# project_id と iap_member を自分の値に書き換える
terraform init
terraform apply
```

## 2回目以降の実行に注意

**Cloud KMSのキーリングと鍵はGoogle Cloudで削除できない。** `terraform destroy`はstateから外すだけで、実体はプロジェクトに残る。同じ名前で再度applyすると409エラーになるので、次のどちらかを選ぶ。

```bash
# A. 既存のものをimportして使う
terraform import google_kms_key_ring.boot_disk \
  projects/PROJECT_ID/locations/asia-northeast1/keyRings/tf-adv-gke-cmek-ring
terraform import google_kms_crypto_key.boot_disk \
  projects/PROJECT_ID/locations/asia-northeast1/keyRings/tf-adv-gke-cmek-ring/cryptoKeys/tf-adv-gke-cmek-boot-disk

# B. 別名を使う（terraform.tfvars に kms_key_ring_name / kms_crypto_key_name を指定）
```

**実際にはBを推奨する。** `terraform destroy`は鍵バージョンの破棄をスケジュールするため、importして再利用しようとしても鍵バージョンが`DESTROY_SCHEDULED`のままで暗号化に使えない（後片付けの節を参照）。

## 検証環境

```
Terraform v1.14.5
provider registry.terraform.io/hashicorp/google v7.46.0
GKE v1.35.7-gke.1027000 (REGULAR channel)
```

## 検証結果

### 1. 初期状態: ディスクは鍵バージョン1

```console
$ terraform apply
Apply complete! Resources: 27 added, 0 changed, 0 destroyed.

$ gcloud compute disks list --filter="name~gke-tf-adv-gke-cmek" \
    --format="table(name,creationTimestamp,diskEncryptionKey.kmsKeyName)"
NAME                                                 CREATION_TIMESTAMP             KMS_KEY_NAME
gke-tf-adv-gke-cmek-tf-adv-gke-cmek-n-aadc2c38-6xm3  2026-09-03T17:03:25.939-07:00  projects/PROJECT_ID/locations/asia-northeast1/keyRings/tf-adv-gke-cmek-ring/cryptoKeys/tf-adv-gke-cmek-boot-disk/cryptoKeyVersions/1
```

Terraformには鍵の**パス**（`.../cryptoKeys/KEY`）しか書いていないが、ディスク側は**バージョンまで含んだ名前**（`.../cryptoKeyVersions/1`）を保持している。この非対称が以降の話の中心になる。

ワークロードを配置して疎通を確認する（`kubectl`は踏み台から実行する）。

```console
$ kubectl apply -f 01-nginx.yaml -f 02-curl.yaml
$ kubectl exec curl-client -- curl -s -o /dev/null -w "HTTP %{http_code}\n" http://nginx-cmek/
HTTP 200
```

### 2. 鍵をローテーションする

```console
$ gcloud kms keys versions create --key=tf-adv-gke-cmek-boot-disk \
    --keyring=tf-adv-gke-cmek-ring --location=asia-northeast1 --primary
Successfully created key version [2] and set it as the primary version.

$ gcloud kms keys versions list --key=tf-adv-gke-cmek-boot-disk \
    --keyring=tf-adv-gke-cmek-ring --location=asia-northeast1
NAME                 STATE
.../cryptoKeyVersions/1  ENABLED
.../cryptoKeyVersions/2  ENABLED
```

### 3. ローテーション後: 既存ノードは何も変わらない

```console
$ gcloud compute disks list --filter="name~gke-tf-adv-gke-cmek" \
    --format="table(name,creationTimestamp,diskEncryptionKey.kmsKeyName.basename())"
NAME                                                 CREATION_TIMESTAMP             KMS_KEY_NAME
gke-tf-adv-gke-cmek-tf-adv-gke-cmek-n-aadc2c38-6xm3  2026-09-03T17:03:25.939-07:00  1

$ kubectl get pods -o custom-columns=NAME:.metadata.name,RESTARTS:.status.containerStatuses[0].restartCount
NAME                          RESTARTS
curl-client                   0
nginx-cmek-5678d55d86-4hfsz   0

$ kubectl exec curl-client -- curl -s -o /dev/null -w "HTTP %{http_code}\n" http://nginx-cmek/
HTTP 200
```

ディスクは鍵バージョン1のまま。`creationTimestamp`も変わっていないのでノードは再作成されていない。Podの再起動も0回。既存データが自動で再暗号化されることはない。

### 4. Terraformはこのずれを検知できない

```console
$ terraform plan
No changes. Your infrastructure matches the configuration.
```

**これが実運用でいちばん危ない点。** Terraformの設定にあるのは鍵のパスだけで、ディスクが実際に使っているバージョンは設定に現れない。「鍵を回したのに古いバージョンのノードが残っている」状態でも、planは差分なしで通る。移行の完了は`terraform plan`ではなく`gcloud compute disks list`で確認する必要がある。

### 5. 新しいノードプールは新しい鍵バージョンを使う

`create_v2_node_pool = true` にして再度apply。

```console
$ terraform apply
Apply complete! Resources: 1 added, 0 changed, 0 destroyed.

$ gcloud compute disks list --filter="name~gke-tf-adv-gke-cmek" \
    --format="table(name,creationTimestamp,diskEncryptionKey.kmsKeyName.basename())"
NAME                                                 CREATION_TIMESTAMP             KMS_KEY_NAME
gke-tf-adv-gke-cmek-tf-adv-gke-cmek-n-aadc2c38-6xm3  2026-09-03T17:03:25.939-07:00  1
gke-tf-adv-gke-cmek-tf-adv-gke-cmek-n-dcf2a6c2-hlmr  2026-09-03T17:06:31.786-07:00  2
```

`gke.tf`の2つのノードプールは`boot_disk_kms_key`に同じ値を書いている。違うのは作られた時刻だけで、それが鍵バージョンを分けている。

### 6. 移行中の断: replicas=1では21秒止まる

`kubectl drain`を実行しながら、Service名に対して毎秒1回HTTPリクエストを送った（`000`はcurlが接続できなかったことを示す）。

```console
$ kubectl drain NODE --ignore-daemonsets --delete-emptydir-data --force --timeout=300s
...
node/gke-tf-adv-gke-cmek-tf-adv-gke-cmek-n-aadc2c38-6xm3 drained

--- probe result (1 sample/sec) ---
200 200 200 200 200 000 000 000 000 000 000 000 000 000 000 000 000 000 000 000 000 000 000 000 000 000 200
     21 000
      6 200
```

**21秒間、1回も応答しなかった。** Podが1個しかないので、退避された瞬間からServiceのエンドポイントが空になり、新しいPodがReadyになるまで受け先がない。

drainの前後だけを見ると両方200なので「疎通継続」と誤って結論できてしまう。移行の断を測るには、drainしている最中にサンプリングし続ける必要がある。

### 7. 2レプリカ + PodDisruptionBudget でも6秒の窓が残る

`04-nginx-ha.yaml`（replicas 2、`podAntiAffinity`、`minAvailable: 1`のPDB）に置き換えて同じことをする。今度はkube-dnsを経路から外すため、Serviceの**ClusterIPに直接**リクエストした。

```console
$ kubectl get pods -o wide
NAME                          READY   STATUS    NODE
nginx-cmek-5c84cd7cd5-6b9mw   1/1     Running   ...-dcf2a6c2-hlmr   (v2)
nginx-cmek-5c84cd7cd5-7jxk7   1/1     Running   ...-aadc2c38-6xm3   (v1)

$ kubectl get pdb nginx-cmek
NAME         MIN AVAILABLE   ALLOWED DISRUPTIONS
nginx-cmek   1               1

--- probe (ClusterIP, 1/sec) ---
000 000 000 200 000 200 200 000 200 200 200 200 200 200 200 200 200 200 200 200 200 200 200 200 200 200 200 200 200 200
      5 000
     25 200
```

完全断はなくなったが、drain直後の約6秒間で5回失敗した。退避されたPodはSIGTERMで即座に終了する一方、他ノードのkube-proxyがエンドポイントを外し終えるまで少し遅れる。その間、すでに落ちたPodにリクエストが振られる。

PDBは「同時に何個まで止めてよいか」を制御するもので、エンドポイント伝播の遅れは面倒を見ない。

### 8. preStopを足すと断がなくなる

`05-nginx-graceful.yaml`で`preStop: sleep 20`と`terminationGracePeriodSeconds: 40`を追加する。

```console
--- probe (ClusterIP, 1/sec) ---
200 200 200 200 200 200 200 200 200 200 200 200 200 200 200 200 200 200 200 200 200 200 200 200 200 200 200 200 200 200 200 200 200
     33 200
```

**失敗0回。** コンテナは終了要求を受けてもすぐには止まらず、エンドポイントが外れ切るまで応答を返し続ける。

| 構成 | 結果 |
|---|---|
| replicas 1 | 21秒の完全断 |
| replicas 2 + anti-affinity + PDB | 約6秒の窓で5回失敗 |
| ＋ preStop sleep 20 | 失敗0回 |

### 9. ノードプールを作り直さなくても新しい鍵バージョンになる

ここが元の想定と違った点。**旧ノードプール（v1）をそのままスケールアウト**してみる。

```console
$ gcloud container clusters resize tf-adv-gke-cmek \
    --node-pool=tf-adv-gke-cmek-np-v1 --num-nodes=2 --zone=asia-northeast1-a

$ gcloud compute disks list --filter="name~gke-tf-adv-gke-cmek" \
    --format="table(name,creationTimestamp,diskEncryptionKey.kmsKeyName.basename())"
NAME                                                 CREATION_TIMESTAMP             KMS_KEY_NAME
gke-tf-adv-gke-cmek-tf-adv-gke-cmek-n-aadc2c38-6xm3  2026-09-03T17:24:23.695-07:00  2
gke-tf-adv-gke-cmek-tf-adv-gke-cmek-n-aadc2c38-pb8w  2026-09-03T17:25:41.514-07:00  2
gke-tf-adv-gke-cmek-tf-adv-gke-cmek-n-dcf2a6c2-hlmr  2026-09-03T17:06:31.786-07:00  2
```

**v1プールに追加されたノードも鍵バージョン2だった。** ノードプールが保持しているのは鍵のパスだけなので、ディスクは作られた時点のprimaryバージョンで暗号化される。

「ブートディスクのCMEKは既存ノードプールで変更できないので新しいノードプールを作る」というのは、**どの鍵を使うか**を変える話。鍵の**バージョン**を進めるだけなら、ノードが作り直されればよく、ノードプールを分ける必要はない。

裏を返せば、自動アップグレード・自動修復・オートスケールでノードが入れ替わるたびに、鍵バージョンは個別に進む。クラスタ内で複数の鍵バージョンが混在するのが通常の状態になる。

### 10. 異常系: 旧ノードが残っているまま旧鍵バージョンを無効化する

鍵バージョン1で暗号化されたノードが稼働している状態で、バージョン1を無効化した。

```console
$ gcloud kms keys versions disable 1 --key=... --keyring=... --location=asia-northeast1
state: DISABLED

$ kubectl get nodes
NAME                                                  STATUS                     AGE
gke-tf-adv-gke-cmek-tf-adv-gke-cmek-n-aadc2c38-6xm3   Ready,SchedulingDisabled   19m
gke-tf-adv-gke-cmek-tf-adv-gke-cmek-n-dcf2a6c2-hlmr   Ready                      16m

$ kubectl exec curl-client -- curl -s -o /dev/null -w "HTTP %{http_code}\n" http://nginx-cmek/
HTTP 200
```

**稼働中は何も起きない。** ディスクはすでに復号された状態でマウントされているため、鍵を無効化しても読み書きは続く。

問題は再起動したときに出る。

```console
$ gcloud compute instances stop gke-tf-adv-gke-cmek-...-6xm3 --zone=asia-northeast1-a
Updated [...].

$ gcloud compute instances start gke-tf-adv-gke-cmek-...-6xm3 --zone=asia-northeast1-a
ERROR: (gcloud.compute.instances.start) HTTPError 400: Cloud KMS error when using key
projects/PROJECT_ID/locations/asia-northeast1/keyRings/tf-adv-gke-cmek-ring/cryptoKeys/tf-adv-gke-cmek-boot-disk/cryptoKeyVersions/1:
... is not enabled, current state is: DISABLED.
```

起動できない。**「無効化しても平気だった」ように見えるのは、たまたま誰も再起動していないだけ。** 次の自動アップグレードや再起動で顕在化する。

### 11. その後GKEが自動修復し、ノードは新しい鍵バージョンで作り直された

上の状態を放置していたら、GKEがノードを復旧させた。

```console
$ gcloud logging read 'protoPayload.methodName=("compute.instances.repair.recreateInstance" OR "v1.compute.instances.insert" OR "v1.compute.instances.delete")' \
    --format="table(timestamp,protoPayload.methodName,protoPayload.authenticationInfo.principalEmail)"
TIMESTAMP                    METHOD_NAME                                PRINCIPAL_EMAIL
2026-09-04T00:24:33.634564Z  v1.compute.instances.insert                service-PROJECT_NUMBER@container-engine-robot.iam.gserviceaccount.com
2026-09-04T00:24:23.010680Z  v1.compute.instances.insert                service-PROJECT_NUMBER@container-engine-robot.iam.gserviceaccount.com
2026-09-04T00:24:21.743331Z  v1.compute.instances.delete                service-PROJECT_NUMBER@container-engine-robot.iam.gserviceaccount.com
2026-09-04T00:23:31.965354Z  compute.instances.repair.recreateInstance  system@google.com
```

ノード名は同じだが`creationTimestamp`が新しくなり、新しいブートディスクは**鍵バージョン2**で作られていた。

つまり、旧鍵バージョンを無効化すると旧ノードは起動できなくなるが、GKEが作り直したノードは新しい鍵バージョンで復旧する。結果的に自己修復はするものの、その間ノードは落ちている。**無効化の前に旧バージョンを使うノードが残っていないことを確認する**という手順は省けない。

### 12. 移行完了後に旧鍵バージョンを無効化する

`keep_v1_node_pool = false` にして apply。

```console
$ terraform apply
Apply complete! Resources: 0 added, 0 changed, 1 destroyed.

$ gcloud container node-pools list --cluster=tf-adv-gke-cmek --zone=asia-northeast1-a
NAME                   STATUS
tf-adv-gke-cmek-np-v2  RUNNING
```

無効化の前に、旧バージョンを使うディスクが残っていないことを確認する。

```console
$ gcloud compute disks list \
    --filter="name~gke-tf-adv-gke-cmek AND diskEncryptionKey.kmsKeyName~cryptoKeyVersions/1$" \
    --format="value(name)" | wc -l
0

$ gcloud kms keys versions disable 1 --key=... --keyring=... --location=asia-northeast1
$ gcloud kms keys versions list --key=... --keyring=... --location=asia-northeast1
NAME  STATE
1     DISABLED
2     ENABLED

$ kubectl exec curl-client -- curl -s -o /dev/null -w "HTTP %{http_code}\n" http://nginx-cmek/
HTTP 200
```

残存0件を確認してから無効化すれば影響は出ない。

### 13. 移行先プールのサイズ

`04-nginx-ha.yaml`は`podAntiAffinity`を`requiredDuringScheduling`で指定しているため、v1プールを削除して1ノードだけになると2つ目のレプリカが配置できない。

```console
$ kubectl get pods
NAME                          READY   STATUS    AGE
nginx-cmek-77d8bffdbc-6lg74   0/1     Pending   106s
nginx-cmek-77d8bffdbc-wph68   1/1     Running   104s
```

移行先のノードプールは、移行元のワークロードを丸ごと収容できるサイズにしてから旧プールを削除する。

なお、`maxSurge`の既定（25%、切り上げて1）のままだと、ローリング更新で3つ目のPodを作ろうとしてアンチアフィニティに阻まれ、ロールアウトが終わらない。

```console
Warning  FailedScheduling  default-scheduler
  0/2 nodes are available: 1 Insufficient cpu, 1 node(s) didn't match pod anti-affinity rules.
```

`04-nginx-ha.yaml`では`maxSurge: 0` / `maxUnavailable: 1`にしている。

### 14. Cloud Loggingに残るもの

Cloud KMSの監査ログには管理操作だけが残る。

```console
$ gcloud logging read 'protoPayload.serviceName="cloudkms.googleapis.com"' \
    --format="table(timestamp,protoPayload.methodName,protoPayload.resourceName.basename())"
TIMESTAMP                       METHOD_NAME                    RESOURCE_NAME
2026-09-04T00:24:32.745742413Z  UpdateCryptoKeyVersion         1
2026-09-04T00:22:54.283612977Z  UpdateCryptoKeyVersion         1
2026-09-04T00:05:30.699113171Z  UpdateCryptoKeyPrimaryVersion  tf-adv-gke-cmek-boot-disk
2026-09-04T00:05:30.558472618Z  CreateCryptoKeyVersion         tf-adv-gke-cmek-boot-disk
2026-09-03T23:55:22.169578524Z  SetIamPolicy                   tf-adv-gke-cmek-boot-disk
2026-09-03T23:55:17.567414618Z  SetIamPolicy                   tf-adv-gke-cmek-boot-disk
2026-09-03T23:55:16.899849634Z  CreateCryptoKey                tf-adv-gke-cmek-boot-disk
2026-09-03T23:55:16.561706287Z  CreateKeyRing                  tf-adv-gke-cmek-ring
```

ローテーション（`CreateCryptoKeyVersion` + `UpdateCryptoKeyPrimaryVersion`）と有効化・無効化（`UpdateCryptoKeyVersion`）は追える。一方、ディスク暗号化で鍵が**使われた**記録（`Encrypt` / `Decrypt`）は出ない。

```console
$ gcloud logging read 'protoPayload.serviceName="cloudkms.googleapis.com" AND protoPayload.methodName=~"Encrypt|Decrypt"' --limit=5
（0件）
```

データアクセス監査ログが既定で無効なため。「どのノードがいつ鍵を使ったか」を追跡したい場合は明示的に有効化する（課金対象）。

## 後片付け

```console
$ terraform destroy
Destroy complete! Resources: 27 destroyed.
```

キーリングと鍵は削除できないので残る。ただし**鍵バージョンは破棄がスケジュールされる**（既定で24時間後）。

```console
$ gcloud kms keys list --keyring=tf-adv-gke-cmek-ring --location=asia-northeast1 \
    --format="table(name.basename(),purpose,primary.name.basename(),primary.state)"
NAME                       PURPOSE          PRIMARY_ID  PRIMARY_STATE
tf-adv-gke-cmek-boot-disk  ENCRYPT_DECRYPT  2           DESTROY_SCHEDULED
```

このため、同じ名前をimportして再利用しても鍵は使えない。再検証するなら`kms_key_ring_name` / `kms_crypto_key_name`に別名を指定する。課金は鍵バージョン単位でごくわずか。

## 参考資料

- [Google Cloud: Use CMEK with GKE](https://cloud.google.com/kubernetes-engine/docs/how-to/using-cmek)
- [Google Cloud: Rotate a key](https://cloud.google.com/kms/docs/rotate-key)
- [Google Cloud: Customer-managed encryption keys](https://cloud.google.com/compute/docs/disks/customer-managed-encryption)
- [Kubernetes: Specifying a Disruption Budget](https://kubernetes.io/docs/tasks/run-application/configure-pdb/)
- [Kubernetes: Pod Lifecycle - Container hooks](https://kubernetes.io/docs/concepts/containers/container-lifecycle-hooks/)
