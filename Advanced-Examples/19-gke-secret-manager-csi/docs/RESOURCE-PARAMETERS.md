# 19 - リソースパラメータ対応

このファイルは**Secret Manager CSIによるPodへのファイルマウント**について対応づけます。自動生成の`docs/PARAMETER.md`とは別物です。VPC/踏み台の基本部分は`11-gke-private-bastion`と同じ構成のため、ここでは差分を中心に記載します。

一次情報:

- [Google Cloud: Use Secret Manager add-on with GKE](https://cloud.google.com/kubernetes-engine/docs/how-to/secret-manager)
- [Google Cloud: Workload Identity Federation for GKE](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity)
- [google_container_cluster](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_cluster)
- [google_secret_manager_secret](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret)

## 確認コマンド

```bash
gcloud container clusters describe "$(terraform output -raw cluster_name)" \
  --zone="$(terraform output -raw zone)" --format="value(secretManagerConfig.enabled)"
gcloud secrets versions list "$(terraform output -raw secret_id)"
gcloud secrets get-iam-policy "$(terraform output -raw secret_id)"
kubectl get secretproviderclass gcp-sm-demo -o yaml
kubectl exec deploy/app-secret-file -- ls -l /var/secrets/
```

## ネットワーク（VPC/踏み台）

`11-gke-private-bastion`と同じ。CIDRのみ再掲する。

| 項目 | 本サンプル |
|---|---|
| GKE Subnet | `10.40.0.0/24`（Pods `10.41.0.0/16`、Services `10.42.0.0/20`） |
| 踏み台Subnet | `10.43.0.0/24` |
| GKEコントロールプレーン | `172.16.4.0/28` |

## google_container_cluster.primary（11との差分）

| 項目 | 本サンプル | 区分 | Terraform | 備考 |
|---|---|---|---|---|
| Secret Manager add-on | 有効 | 明示 | `secret_manager_config { enabled = true }` | ノードにCSIドライバ（`secrets-store-gke.csi.k8s.io`）が入る。これがないとPodの`csi`ボリュームが解決できない |
| Workload Identity | 有効（`11`と同じ） | 明示 | `workload_identity_config.workload_pool` | KSAをIAM principalとして使うための前提 |

## google_secret_manager_secret.demo

| 項目 | 本サンプル | 区分 | Terraform | 備考 |
|---|---|---|---|---|
| シークレットの器 | 作成する | 明示 | `google_secret_manager_secret` | |
| **シークレットの値** | **Terraformでは作らない** | 意図的に省略 | （`google_secret_manager_secret_version`を使わない） | `secret_data`は`terraform.tfstate`に平文で保存される。値は`gcloud secrets versions add`で投入する |
| レプリケーション | 自動 | 明示 | `replication { auto {} }` | リージョン指定が要る場合は`user_managed`を使う |

## IAM（GSAを作らない設計）

| 項目 | 本サンプル | 区分 | Terraform | 備考 |
|---|---|---|---|---|
| principal | `principal://iam.googleapis.com/projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/PROJECT_ID.svc.id.goog/subject/ns/NAMESPACE/sa/KSA_NAME` | 明示 | `local.ksa_principal` | **KSAを直接IAMのメンバーにする。** Google Service Accountの作成、`iam.gke.io/gcp-service-account`アノテーション、鍵JSONのいずれも不要 |
| ロール | `roles/secretmanager.secretAccessor` | 明示 | `google_secret_manager_secret_iam_member.ksa_accessor` | シークレット単位で付与。プロジェクト全体には付けない |
| プロジェクト番号 | `data.google_project.current.number` | 参照 | `data "google_project"` | principalにはプロジェクト**番号**が必要（IDではない） |

principalの文字列には名前空間とKSA名が埋め込まれる。`k8s/01-serviceaccount.yaml`と`var.k8s_namespace` / `var.k8s_service_account_name`がずれると、権限が付かずマウントに失敗する。

## SecretProviderClass（Kubernetesリソース、Terraform管理外）

| 項目 | 本サンプル | 備考 |
|---|---|---|
| `provider` | `gke` | Secret Manager add-on用。汎用のSecrets Store CSI Driverとは値が異なる |
| `resourceName` | `projects/PROJECT/secrets/SECRET/versions/latest` | `latest`指定でも、新バージョンはPodを作り直すまで反映されない |
| `path` | `db-password.txt` | マウント先ディレクトリ内のファイル名 |

## Deployment（csiボリューム）

| 項目 | 本サンプル | 備考 |
|---|---|---|
| `driver` | `secrets-store-gke.csi.k8s.io` | `secret_manager_config`で導入されるドライバ名 |
| `mountPath` | `/var/secrets` | `readOnly: true`でマウント |
| `serviceAccountName` | `app-ksa` | IAM principalに含まれるKSA名と一致させる |

Pod specにシークレットの**値**は現れない。`kubectl describe pod`で見えるのは`SecretProviderClass`の名前だけ（実測で0件を確認）。

## 実測で確認した挙動

| 項目 | 結果 | 備考 |
|---|---|---|
| ノードのマシンタイプ | `e2-small`では不足 | CSIドライバのDaemonSet＋GKE標準コンポーネントで割り当て可能CPUの99%が埋まり、アプリPodが`Insufficient cpu`で`Pending`。`e2-medium`が既定 |
| `latest`指定時の更新反映 | **自動では反映されない** | 新バージョン追加後5分待っても稼働中Podのファイルは旧値のまま。`kubectl rollout restart`で反映される |
| 稼働中PodからIAM権限を削除 | **影響を受けない** | マウント済みボリュームはノード上に保持され、読み続けられる |
| 権限がない状態でPod再作成 | `FailedMount` | `PermissionDenied` / `IAM_PERMISSION_DENIED` / `secretmanager.versions.access`。権限を戻すと自動復旧 |
| 版固定（`versions/1`） | 旧版を保持 | `latest`側が更新されても影響を受けない |
| Private Google Access | 到達できる | ノードに外部IPがない状態（`natIP`空）で`privateIpGoogleAccess=true`によりSecret Manager APIへ到達 |

## Cloud Loggingに残るもの

| ログ | クエリ | 内容 |
|---|---|---|
| CSIドライバ | `resource.type="k8s_container" AND resource.labels.pod_name=~"csi-secrets-store"` | 成功時は`node publish volume complete`（Pod名・所要時間つき）、失敗時は`PermissionDenied`の詳細。`jsonPayload.message`に入る |
| Podイベント | `resource.type="k8s_pod" AND jsonPayload.reason="FailedMount"` | `kubectl describe pod`と同じ内容 |
| Secret Manager監査ログ | `protoPayload.serviceName="secretmanager.googleapis.com"` | `CreateSecret` / `AddSecretVersion` / `SetIamPolicy` / `DeleteSecret`（管理操作）のみ |

**`AccessSecretVersion`（値の読み取り）は既定では監査ログに記録されない。** 追跡するにはデータアクセス監査ログの有効化が必要（既定で無効、課金対象）。

未指定（デフォルト）の項目はコンソール/APIのデフォルト値に従う。推測での記載はしない。
