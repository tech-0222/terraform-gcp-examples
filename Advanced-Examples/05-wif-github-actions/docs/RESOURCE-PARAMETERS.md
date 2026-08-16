# 05 - リソースパラメータ対応

このファイルは **GitHub Actions 向け Workload Identity Federation** について対応づけます。自動生成の `PARAMETER.md` とは別物です。

一次情報:

- [WIF with deployment pipelines](https://cloud.google.com/iam/docs/workload-identity-federation-with-deployment-pipelines)
- [google_iam_workload_identity_pool](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/iam_workload_identity_pool)
- [google_iam_workload_identity_pool_provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/iam_workload_identity_pool_provider)
- [GitHub OIDC](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)

## 確認コマンド

```bash
gcloud iam workload-identity-pools describe tf-adv-github-pool --location=global --format=json
gcloud iam workload-identity-pools providers describe tf-adv-github-provider \
  --location=global --workload-identity-pool=tf-adv-github-pool --format=json
```

## Workload Identity Pool / Provider

| 項目 | 本サンプル | Terraform / 公式 |
|---|---|---|
| pool_id | `tf-adv-github-pool` | `workload_identity_pool_id` |
| disabled | false | |
| provider | GitHub OIDC | `oidc.issuer_uri = https://token.actions.githubusercontent.com` |
| 属性マッピング | `google.subject` ← `assertion.sub` ほか | GitHub トークンの claim |
| 条件 | `assertion.repository == 'org/repo'` | 単一リポジトリに制限 |
| SA なりすまし | `roles/iam.workloadIdentityUser` | メンバーは `principalSet://iam.googleapis.com/POOL/attribute.repository/org/repo` |

長期の SA 鍵は使いません。

## デモ GCS

| 項目 | 本サンプル | 備考 |
|---|---|---|
| UBLA / PAP | true / enforced | |
| IAM | `roles/storage.objectViewer` のみ | Project 広範なロールは付けない |
| オブジェクト | `hello-wif.txt` | workflow が読み取れることを確認する用 |
