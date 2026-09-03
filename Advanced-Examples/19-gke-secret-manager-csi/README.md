# 19 - GKE Secret Manager CSI（Podへのファイルマウント）

GKEのSecret Manager add-onを使い、Secret Managerの値を**Podのファイルとしてマウント**するサンプルです。

環境変数でシークレットを渡すと、`kubectl describe pod`やプロセス一覧から見えてしまう懸念があります。ファイルマウントなら、Podのspecにシークレットの値は一切現れません。

マウントできることだけでなく、**更新は自動で反映されるのか**、**権限を失ったらどうなるのか**、**ログに何が残るのか**まで実測しています。

## この構成の要点

### 1. Terraformにシークレットの値を書かない

`google_secret_manager_secret_version`の`secret_data`を使うと、**平文が`terraform.tfstate`に載ります**。本サンプルは器（`google_secret_manager_secret`）だけをTerraformで作り、値は`gcloud secrets versions add`で投入します。

### 2. GSAを作らない

Workload Identity Federation for GKEでは、KubernetesのServiceAccountを**直接IAMのprincipalとして指定**できます。

```hcl
locals {
  ksa_principal = "principal://iam.googleapis.com/projects/${data.google_project.current.number}/locations/global/workloadIdentityPools/${var.project_id}.svc.id.goog/subject/ns/${var.k8s_namespace}/sa/${var.k8s_service_account_name}"
}

resource "google_secret_manager_secret_iam_member" "ksa_accessor" {
  secret_id = google_secret_manager_secret.demo.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = local.ksa_principal
}
```

Google Service Accountの作成、`iam.gke.io/gcp-service-account`アノテーション、鍵JSONのいずれも不要です。

### 3. ノードは e2-medium 以上が必要

`e2-small`（2 vCPU）ではPodが`Pending`のまま起動しません。

```text
0/1 nodes are available: 1 Insufficient cpu.
```

Secret Manager CSIドライバのDaemonSetとGKE標準コンポーネントで、ノードの割り当て可能CPUの**99%**が埋まります。本サンプルは`e2-medium`を既定にしています。

## 関係するサービス

| サービス | 役割 |
|---|---|
| GKE | プライベートクラスタ（Standard、ゾーナル）。`secret_manager_config`でCSIドライバを導入 |
| Secret Manager | シークレットの保管先 |
| Compute Engine | 踏み台VM（外部IPなし） |

ノードは外部IPを持たず、`private_ip_google_access = true`（`network.tf`）でSecret Manager APIへ到達します。Cloud NATもありますが、Google APIへは Private Google Access が使われます。

## 前提条件

- ADC認証済み
- **課金有効な**検証用Project

## ファイル構成

```text
19-gke-secret-manager-csi/
├── README.md
├── docs/
│   ├── PARAMETER.md              # terraform-docs（自動生成。手動編集しない）
│   └── RESOURCE-PARAMETERS.md    # コンソール / API / Terraform の対応（手書き）
├── DEPENDENCY-GRAPH.svg          # terraform graph（自動生成。手動編集しない）
├── .terraform.lock.hcl
├── versions.tf
├── provider.tf
├── variables.tf
├── network.tf         # VPC / Subnet×2 / Cloud NAT / Firewall
├── bastion.tf          # 踏み台: SA / IAM / VM
├── gke.tf              # GKE: プライベートクラスタ + secret_manager_config
├── secret.tf            # Secret Managerの器×2 + KSAへのIAM（値は含まない）
├── outputs.tf
├── terraform.tfvars.example
└── k8s/
    ├── 01-serviceaccount.yaml       # KSA（annotationなし）
    ├── 02-secretproviderclass.yaml  # どのシークレットをどのパスに出すか
    ├── 03-deployment.yaml           # csiボリュームでマウント
    └── examples/
        ├── 01-multi-secret-one-volume.yaml  # 複数シークレットを1ボリュームに
        └── 02-pinned-version.yaml           # 版を固定してマウント
```

## 設定方法

```bash
cd Advanced-Examples/19-gke-secret-manager-csi
cp terraform.tfvars.example terraform.tfvars
```

```hcl
project_id = "your-project-id"
iap_member = "user:you@example.com"
```

## 使用方法

```bash
terraform init
terraform fmt -check
terraform validate
terraform plan
terraform apply
```

## 確認方法

### 1. シークレットの値を投入する

Terraformの外で行います。

```bash
printf '%s' 'super-secret-value' | gcloud secrets versions add \
  "$(terraform output -raw secret_id)" --data-file=- \
  --project="$(terraform output -raw project_id)"

printf '%s' 'api-key-abc123' | gcloud secrets versions add \
  "$(terraform output -raw secret_id_second)" --data-file=- \
  --project="$(terraform output -raw project_id)"
```

`--data-file=-`で標準入力から読ませることで、シェル履歴にもファイルにも値が残りません。

### 2. マニフェストを適用する

`SecretProviderClass`のプレースホルダを置換してから転送します。

```bash
sed -e "s|__PROJECT_ID__|$(terraform output -raw project_id)|" \
    -e "s|__SECRET_ID__|$(terraform output -raw secret_id)|" \
  k8s/02-secretproviderclass.yaml > /tmp/02-secretproviderclass.yaml

for f in k8s/01-serviceaccount.yaml /tmp/02-secretproviderclass.yaml k8s/03-deployment.yaml; do
  gcloud compute scp "$f" \
    "$(terraform output -raw bastion_name):/tmp/$(basename "$f")" \
    --zone="$(terraform output -raw zone)" --tunnel-through-iap \
    --project="$(terraform output -raw project_id)"
done
```

```bash
# 踏み台の中で実行
gcloud container clusters get-credentials "$(terraform output -raw cluster_name)" \
  --zone="$(terraform output -raw zone)" --project="$(terraform output -raw project_id)"
kubectl apply -f /tmp/01-serviceaccount.yaml -f /tmp/02-secretproviderclass.yaml -f /tmp/03-deployment.yaml
kubectl wait --for=condition=ready pod -l app=app-secret-file --timeout=180s
```

### 3. Podの中でファイルが読めることを確認する

Podが起動したことと、シークレットが実際に読めることは別です。

```bash
# 踏み台の中で実行
kubectl exec deploy/app-secret-file -- ls -l /var/secrets/
kubectl exec deploy/app-secret-file -- cat /var/secrets/db-password.txt

# Pod specに値が現れないことの確認（0件になる）
kubectl get pod -l app=app-secret-file -o yaml | grep -c 'super-secret-value'
```

### 4. シークレットを更新しても自動では反映されない

`versions/latest`を指定していても、稼働中のPodのファイルは**更新されません**。

```bash
printf '%s' 'UPDATED-value-v2' | gcloud secrets versions add \
  "$(terraform output -raw secret_id)" --data-file=- \
  --project="$(terraform output -raw project_id)"
```

```bash
# 踏み台の中で実行。5分待っても古い値のまま
kubectl exec deploy/app-secret-file -- cat /var/secrets/db-password.txt
```

反映にはPodの作り直しが必要です。

```bash
kubectl rollout restart deploy/app-secret-file
kubectl rollout status deploy/app-secret-file --timeout=240s
kubectl exec deploy/app-secret-file -- cat /var/secrets/db-password.txt   # 新しい値になる
```

### 5. 権限を外したときの挙動を確認する（apply成功とは別の確認）

IAMバインディングが実際に効いているかは、付いている状態で成功することだけでは確認できません。

```bash
terraform apply -var="grant_ksa_secret_access=false"
```

**稼働中のPodは影響を受けません。** マウント済みのボリュームはノード上に保持されているため、そのまま読み続けられます。

```bash
# 踏み台の中で実行。まだ読める
kubectl exec deploy/app-secret-file -- cat /var/secrets/db-password.txt
```

影響が出るのは**Podを作り直したとき**です。

```bash
kubectl rollout restart deploy/app-secret-file
kubectl get pods -l app=app-secret-file          # 新しいPodがContainerCreatingのまま
kubectl describe pod -l app=app-secret-file | grep -A 5 Events
```

```text
Warning  FailedMount  kubelet  MountVolume.SetUp failed for volume "secret-vol" :
  rpc error: code = PermissionDenied desc = Permission 'secretmanager.versions.access'
  denied on resource (or it may not exist).
  ... reason = IAM_PERMISSION_DENIED domain = iam.googleapis.com
```

古いPodは動き続けたまま、新しいPodだけが起動できない状態になります。権限を戻すと自動的に復旧します。

```bash
terraform apply
```

### 6. Cloud Loggingで何が残るかを確認する

**CSIドライバのログ**（成功・失敗の両方が残る）:

```bash
gcloud logging read \
  'resource.type="k8s_container" AND resource.labels.pod_name=~"csi-secrets-store"' \
  --project="$(terraform output -raw project_id)" --limit=5 --freshness=30m \
  --format="value(timestamp,severity,jsonPayload.message)"
```

```text
"node publish volume complete" targetPath="/var/lib/kubelet/pods/.../mount" pod="default/app-secret-file-..." time="277.0441ms"
```

**Podイベント**（`kubectl describe`と同じ内容）:

```bash
gcloud logging read \
  'resource.type="k8s_pod" AND jsonPayload.reason="FailedMount"' \
  --project="$(terraform output -raw project_id)" --limit=3 --freshness=30m \
  --format="value(timestamp,jsonPayload.message)"
```

**Secret Managerの監査ログ**には注意が必要です。

```bash
gcloud logging read \
  'protoPayload.serviceName="secretmanager.googleapis.com"' \
  --project="$(terraform output -raw project_id)" --limit=20 --freshness=30m \
  --format="value(protoPayload.methodName)" | sort -u
```

```text
google.cloud.secretmanager.v1.SecretManagerService.AddSecretVersion
google.cloud.secretmanager.v1.SecretManagerService.CreateSecret
google.cloud.secretmanager.v1.SecretManagerService.DeleteSecret
google.cloud.secretmanager.v1.SecretManagerService.SetIamPolicy
```

管理操作は記録されますが、**値の読み取り（`AccessSecretVersion`）は既定では記録されません**。「誰がいつシークレットを読んだか」を追跡するには、データアクセス監査ログを明示的に有効化する必要があります（既定で無効、かつ課金対象）。

### 7. 複数シークレットを1つのボリュームにマウントする

```bash
sed -e "s|__PROJECT_ID__|$(terraform output -raw project_id)|g" \
    -e "s|__SECRET_ID__|$(terraform output -raw secret_id)|g" \
    -e "s|__SECRET_ID_2__|$(terraform output -raw secret_id_second)|g" \
  k8s/examples/01-multi-secret-one-volume.yaml > /tmp/ex01.yaml
# 踏み台へ転送して kubectl apply
```

```bash
kubectl exec deploy/app-multi-secret -- ls /var/secrets/
```

```text
api-key.txt
db-password.txt
```

1つの`SecretProviderClass`に複数の`resourceName`を並べると、同じボリューム内に別ファイルとして配置されます。

### 8. 版を固定してマウントする

`versions/latest`ではなく`versions/1`のように明示すると、新しいバージョンを追加しても**その版を保持し続けます**。

```bash
sed -e "s|__PROJECT_ID__|$(terraform output -raw project_id)|g" \
    -e "s|__SECRET_ID__|$(terraform output -raw secret_id)|g" \
  k8s/examples/02-pinned-version.yaml > /tmp/ex02.yaml
# 踏み台へ転送して kubectl apply
```

```bash
kubectl exec deploy/app-pinned-secret -- cat /var/secrets/db-password-v1.txt   # version 1 の値
kubectl exec deploy/app-secret-file   -- cat /var/secrets/db-password.txt      # latest の値
```

ローテーション時に意図せず新しい値を拾わせたくない場合に使えます。

## 削除方法

```bash
terraform destroy
```

**必ず destroy してください。** GKE・踏み台VM・Cloud NATは利用中に料金が発生します。Secret Managerのシークレットとその全バージョンも削除されます。

## 注意点 / 費用

- **シークレットの値をTerraformで管理しないでください。** `secret_data`はtfstateに平文で残ります。本サンプルは器だけを作る設計です
- **ノードは`e2-medium`以上が必要です。** `e2-small`ではCSIドライバのDaemonSetでCPUが埋まり、アプリのPodが`Pending`のままになります
- **`latest`指定でも自動更新されません。** シークレットを更新したらPodを作り直す必要があります
- **値の読み取りは既定では監査ログに残りません。** 追跡が必要ならデータアクセス監査ログを有効化してください
- KSAの名前空間・名前はIAM principalの文字列に埋め込まれます。`k8s/01-serviceaccount.yaml`とTerraform変数がずれると、権限が付かずマウントに失敗します
