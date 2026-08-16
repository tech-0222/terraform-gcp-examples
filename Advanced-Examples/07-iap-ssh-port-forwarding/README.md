# 07 - IAP SSH Port Forwarding

外部IPを持たないCompute Engine VMへIAP経由でSSH接続し、SSH Local Port Forwardingを使ってVM上のnginxへHTTP接続するサンプルです。

## 確認すること

- VMへ外部IPを付けずにIAP経由でSSH接続できる
- IAP用Source RangeからVMのtcp/22だけを許可できる
- HTTPのtcp/80をFirewallで公開せず、SSH Tunnel内から確認できる
- `127.0.0.1:8080`からVMの`127.0.0.1:80`へ転送し、HTTP 200を取得できる
- `terraform destroy`で削除できる

## Advanced 01との違い

`01-gce-iap-vpc`はIAP SSH、OS Login、IAMを中心に確認します。このサンプルでは、その接続経路にSSH Local Port Forwardingとnginxを追加し、非公開HTTP EndpointをEnd-to-Endで確認します。

## 構成

```text
Operator
  | gcloud compute ssh --tunnel-through-iap
  | -L 127.0.0.1:8080:127.0.0.1:80
  v
IAP TCP forwarding
  | 35.235.240.0/20 -> tcp/22
  v
Spot VM (no external IP)
  `- nginx :80

Spot VM -> Cloud NAT -> package repositories
```

Cloud NATはVMがnginxをInstallするためのOutbound経路です。IAPからVMへのInbound経路ではありません。

## 作成されるGoogle Cloudリソース

リソースの明示設定と公式ドキュメント上の既定値の対応は `docs/RESOURCE-PARAMETERS.md` を参照してください。`PARAMETER.md` は terraform-docs の自動生成です。


- 必要なGoogle Cloud API
- Custom VPC / Subnet
- Cloud Router / Cloud NAT
- IAP SSH用Firewall
- VM用Service Account
- 外部IPなしのSpot VM
- Project IAM Member
  - `roles/iap.tunnelResourceAccessor`
  - `roles/compute.osLogin`
- Instance単位のIAP Tunnel IAM Member

## 前提条件

- 課金が有効な検証用Google Cloud Project
- TerraformとGoogle Cloud CLI
- Application Default Credentialsを設定済み
- API、Compute Engine、Network、Service Account、Project IAMを操作できる権限
- `iap_member`に指定するUserまたはPrincipal

## 設定

```bash
cp terraform.tfvars.example terraform.tfvars
```

```hcl
project_id = "your-project-id"
iap_member = "user:you@example.com"
```

## 実行

```bash
terraform init
terraform fmt -check
terraform validate
terraform plan
terraform apply
```

Startup Scriptが完了し、nginxが起動するまで少し待ちます。必要に応じてSerial Port Outputを確認します。

```bash
gcloud compute instances get-serial-port-output \
  "$(terraform output -raw instance_name)" \
  --zone="$(terraform output -raw zone)" \
  --project="$(terraform output -raw project_id)" | tail -50
```

## IAP SSH接続

```bash
eval "$(terraform output -raw iap_ssh_command)"
```

VM内でnginxを確認できます。

```bash
sudo systemctl status nginx --no-pager
curl --fail --show-error http://127.0.0.1/
```

## HTTP Port Forwarding

Terminal 1でTunnelを開始します。このCommandはTunnelを維持するため、停止したように見える状態が正常です。

```bash
eval "$(terraform output -raw http_tunnel_command)"
```

Terminal 2でHTTPを確認します。

```bash
eval "$(terraform output -raw http_check_command)"
```

次のHTMLが返れば成功です。

```html
<h1>IAP SSH port forwarding works</h1>
```

Local Bindを`127.0.0.1`へ明示しているため、IPv6 Loopbackが利用できない環境での`bind [::1]: Cannot assign requested address`を避けられます。

## トラブルシューティング

### SSHまたはTunnelがPermission deniedになる

`iap_member`、IAP Tunnel IAM、OS Login IAM、VMのLogin権限を確認します。Organization Policyによって追加権限が必要な場合があります。

### localhost:8080が使用中

`local_port`を変更して再度Applyします。

```hcl
local_port = 18080
```

### HTTPがConnection refusedになる

Startup Scriptの完了とnginxの状態を確認します。外部IPなしのVMがPackage Repositoryへ出るため、Cloud NATも正常である必要があります。

## 削除

Tunnelを`Ctrl+C`で終了してから実行します。

```bash
terraform destroy
```

## 注意点 / 費用

- Spot VMは中断される可能性があるため、短時間の検証用途です
- VM、Disk、Cloud NATの利用には料金が発生します。検証後は必ずdestroyします
- Cloud NATはGateway稼働時間やData Processingに応じて課金されます
- tcp/80はFirewallで許可していません。HTTPはSSH Tunnel内だけで到達します
- Project IAM Memberはdestroy時に削除されるため、既存の同Role付与との関係を確認します
- Service Account Keyは作成しません

## 検証状況

2026-08-12に`tech-0222-tf-examples`で実環境検証を実施しました。

- `terraform init`、`terraform fmt -check`、`terraform validate`が成功
- `terraform plan`で14リソースの作成、変更0、削除0を確認
- `terraform apply`が成功し、VMが外部IPを持たないことを確認
- IAP経由のSSH接続に成功し、VM上のnginxが`active`であることを確認
- SSH Port Forwarding経由の`http://127.0.0.1:8080/`でHTTP 200と期待したHTMLを確認
- 検証後に`terraform destroy`を実行し、14リソースを削除
- Terraform Stateが空であり、VMとVPCがGoogle Cloud API上に残っていないことを確認

`disable_on_destroy = false`としているため、必要なAPIの有効化状態はdestroy後も維持されます。

## 参考資料

- [IAP TCP forwarding](https://cloud.google.com/iap/docs/using-tcp-forwarding)
- [Connect to Linux VMs using IAP](https://cloud.google.com/compute/docs/connect/ssh-using-iap)
- [OpenSSH port forwarding](https://man.openbsd.org/ssh#L)
