# Repository conventions

このリポジトリでTerraformサンプルを追加する際の基本ルールです。

## 1. サンプルは独立したRoot Moduleにする

各 `examples/<番号>-<名前>/` は、可能な限りそのディレクトリだけで検証できる構成にします。

基本ファイル:

```text
README.md
versions.tf
provider.tf
variables.tf
main.tf または data.tf
outputs.tf
terraform.tfvars.example
```

必要に応じてファイルを追加します。

## 2. 検証フロー

原則として以下を確認します。

```bash
terraform init
terraform fmt -check
terraform validate
terraform plan
terraform apply
# GCP側の動作確認
terraform destroy
```

リソースを作成しないサンプルでは `apply` / `destroy` を省略できます。

## 3. Secretをコミットしない

以下はコミットしません。

- `terraform.tfvars`
- `*.tfstate`
- Service Account Key JSON
- Access Token
- Password / API Key / Secret

公開可能な入力例は `terraform.tfvars.example` に記載します。

## 4. ProviderとTerraform Version

各サンプルの `versions.tf` で明示します。

Providerのメジャーバージョンは意図せず更新されないよう制約を設定します。

## 5. 命名

サンプルディレクトリは実行順・記事化の順番を分かりやすくするため、2桁の番号を付与します。

```text
00-provider-check
01-project-service
02-network
```

Terraform Resource名は、サンプル内で役割が分かる簡潔な名前を使用します。

## 6. READMEに書く内容

各サンプルのREADMEには最低限以下を記載します。

- 何を検証するか
- 作成されるGCPリソース
- 前提条件
- 使用方法
- 確認方法
- 削除方法
- 注意点 / 費用
