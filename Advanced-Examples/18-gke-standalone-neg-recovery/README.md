# 18 - GKE Standalone NEG の削除・再作成とLBバックエンドの復旧

GKEのServiceから自動作成される**スタンドアロンNEG**を外部Application LBのバックエンドにした構成で、**NEGが消えたとき・クラスタを作り直したときにLBが自動で復旧するのか**を実測するサンプルです。

`14-gke-bastion-ilb-multi-neg`はNEGを**作る**ところまでを扱いました。本サンプルは、その先の「壊れたときどうなるか」を扱います。

## 検証すること

1. **正常系**: LB経由でPodへ到達できること（HTTP 200）
2. **検証1**: Serviceを削除してNEGが消えた後、LBはどうなるか。Serviceを再作成してNEGが同名で戻れば、バックエンドは自動で再設定されるか
3. **検証2**: LBを残したままGKEクラスタを作り直したとき、同名NEGとの関係はどうなるか

## 構成

| 要素 | 内容 |
|---|---|
| GKE | プライベートクラスタ（Standard、**リージョナル・2ゾーン**） |
| NEG | GKEがServiceのアノテーションから**ゾーンごとに**自動作成（Terraform管理外） |
| LB | グローバル外部Application LB（HTTP）。バックエンドは上記NEG |
| 踏み台 | 外部IPなし、IAP SSHのみ |

GKEをリージョナル・複数ゾーンにしているのは、NEGがゾーンごとに作られるためです。単一ゾーンだと「複数NEGを束ねたバックエンド」という現実的なケースになりません。

## NEGはTerraform管理外

NEGはGKEのNEGコントローラがServiceの`cloud.google.com/neg`アノテーションから作ります。Terraformは`data`ソースで**読むだけ**です。

```hcl
data "google_compute_network_endpoint_group" "standalone" {
  for_each = var.enable_lb ? toset(var.gke_zones) : toset([])
  name     = var.neg_name
  zone     = each.value
}
```

この非対称性（GKEが作り、Terraformが参照する）が、本サンプルで扱う不整合の原因になります。

## 前提条件

- ADC認証済み
- **課金有効な**検証用Project

## ファイル構成

```text
18-gke-standalone-neg-recovery/
├── README.md
├── docs/
│   ├── PARAMETER.md              # terraform-docs（自動生成。手動編集しない）
│   └── RESOURCE-PARAMETERS.md    # コンソール / API / Terraform の対応（手書き）
├── DEPENDENCY-GRAPH.svg          # terraform graph（自動生成。手動編集しない）
├── .terraform.lock.hcl
├── versions.tf
├── provider.tf
├── variables.tf
├── network.tf         # VPC / Subnet×2 / Cloud NAT / Firewall（IAP SSH・LBヘルスチェック）
├── bastion.tf          # 踏み台: SA / IAM / VM
├── gke.tf              # GKE: リージョナル・2ゾーンのプライベートクラスタ
├── lb.tf                # 外部LB（enable_lbで有効化）。NEGはdataで参照
├── outputs.tf
├── terraform.tfvars.example
└── k8s/
    └── neg-app.yaml           # nginx Deployment + Service（NEGアノテーション付き）
```

## 設定方法

```bash
cd Advanced-Examples/18-gke-standalone-neg-recovery
cp terraform.tfvars.example terraform.tfvars
```

```hcl
project_id = "your-project-id"
iap_member = "user:you@example.com"
```

## 使用方法（2段階apply）

NEGはPodとServiceを作った後にしか存在しません。`enable_lb=false`（デフォルト）でクラスタを作り、Podをデプロイし、NEGの作成を待ってから`enable_lb=true`でLBを作ります。

```bash
terraform init
terraform fmt -check
terraform validate
terraform plan
terraform apply
```

**NEGが存在しない状態で`enable_lb=true`にすると、`plan`の時点で失敗します。**

```text
Error: projects/PROJECT/zones/asia-northeast1-a/networkEndpointGroups/tf-adv-negrec-neg not found
```

`data`ソースはplan時に解決されるため、`14-gke-bastion-ilb-multi-neg`（URL文字列でNEGを参照。apply時に404）とはエラーの出るタイミングが違います。

## 確認方法

### 1. アプリをデプロイし、NEGが作られたことを確認する

```bash
gcloud compute scp k8s/neg-app.yaml \
  "$(terraform output -raw bastion_name):/tmp/neg-app.yaml" \
  --zone="$(terraform output -raw zone)" --tunnel-through-iap \
  --project="$(terraform output -raw project_id)"
```

```bash
# 踏み台の中で実行
gcloud container clusters get-credentials "$(terraform output -raw cluster_name)" \
  --region="$(terraform output -raw region)" --project="$(terraform output -raw project_id)"
kubectl apply -f /tmp/neg-app.yaml
kubectl wait --for=condition=ready pod -l app=neg-app --timeout=120s
```

ローカルでNEGの作成を待ちます（1〜2分）。

```bash
gcloud compute network-endpoint-groups list \
  --filter="name=$(terraform output -raw neg_name)"
```

### 2. LBを作成し、正常系を確認する

```bash
terraform apply -var="enable_lb=true"
```

```bash
gcloud compute backend-services get-health "$(terraform output -raw backend_service_name)" --global
curl -s -o /dev/null -w "%{http_code}\n" "http://$(terraform output -raw lb_ip)/"
```

`HEALTHY`と`200`を確認します（LBの初期化に数分かかります）。

### 3. 検証1: Serviceを削除する

```bash
# 踏み台の中で実行
kubectl delete svc neg-app-svc
```

NEGとバックエンドの状態、疎通を確認します。

```bash
gcloud compute network-endpoint-groups list --filter="name=$(terraform output -raw neg_name)"
gcloud compute backend-services get-health "$(terraform output -raw backend_service_name)" --global
curl -s -o /dev/null -w "%{http_code}\n" "http://$(terraform output -raw lb_ip)/"
```

### 4. 検証1の復旧: Serviceを再作成する

```bash
# 踏み台の中で実行
kubectl apply -f /tmp/neg-app.yaml
```

NEGが同名で戻った後、**バックエンドが自動で再設定されるか**を確認します。戻らない場合は`terraform apply`で再付与します。

```bash
gcloud compute backend-services describe "$(terraform output -raw backend_service_name)" --global --format="value(backends[].group)"
terraform apply -var="enable_lb=true"
```

### 5. 検証2: クラスタを作り直す

LB・Firewall・静的IPは残したまま、クラスタとノードプールだけを削除します。

```bash
terraform destroy -var="enable_lb=true" \
  -target=google_container_node_pool.primary \
  -target=google_container_cluster.primary
terraform apply -var="enable_lb=true"
```

再作成後、Serviceを適用してNEGとLBの状態を確認します。旧クラスタ由来のNEGが残っている場合、`kubectl describe svc`に`SyncNetworkEndpointGroupFailed`が出ることがあります。

## 削除方法

```bash
terraform destroy -var="enable_lb=true"
```

**必ず destroy してください。** GKE（2ノード）・LB・踏み台VM・Cloud NATは利用中に料金が発生します。

## 注意点 / 費用

- GKEはリージョナル・2ノード構成のため、単一ノードの例より高コストです
- NEGはTerraform管理外のため、`terraform destroy`では消えません。クラスタを消せばGKEが片付けますが、残った場合は`gcloud compute network-endpoint-groups delete`で手動削除します
- バックエンドから参照されているNEGは削除できません。先に`gcloud compute backend-services remove-backend`が必要です
