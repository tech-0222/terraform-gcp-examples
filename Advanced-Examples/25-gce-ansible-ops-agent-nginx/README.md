# 25. TerraformとAnsibleの境界はどこか

Terraformはマシンを作る。中で動くものを設定するのはAnsible。よく聞く分担だが、その受け渡しは自動では繋がらない。

- Terraformが「成功」を返しても、中の設定が終わっているとは限らない
- playbookを直しても、既存のVMには自動では届かない
- Terraformが知らない順序依存がある

GCEにOps AgentとNginxを入れる最小構成で、この境界を実測する。

## 構成

| リソース | 用途 |
|---|---|
| VPC + サブネット + Cloud NAT | VMは外部IPなし。外向きはNAT経由 |
| ファイアウォール2つ | IAP経由のSSH（22）とHTTP（80） |
| GCSバケット | Ansible資材の置き場。`force_destroy = true` |
| **専用サービスアカウント** | Compute Engineの既定SAは使わない |
| GCE VM 1台 | `metadata_startup_script`でAnsibleを起動 |

## 役割分担

| | 担当 |
|---|---|
| **Terraform** | マシン、ID、ネットワーク、ファイアウォール |
| **Ansible** | パッケージ、サービス設定、ディスク上のファイル |

受け渡しは`metadata_startup_script`。GCSから資材を同期して`ansible-playbook`を実行する。

## サービスアカウントは新規に作る

既定のCompute Engine SAは権限が広い。専用のSAを作り、最小権限を与える。

```hcl
resource "google_service_account" "vm" {
  account_id = "${var.instance_name}-sa"
}

# バケット単位。プロジェクト全体には付けない
resource "google_storage_bucket_iam_member" "vm_read" {
  bucket = google_storage_bucket.ansible.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.vm.email}"
}

# Ops Agent がログとメトリクスを送るのに要る
resource "google_project_iam_member" "vm" {
  for_each = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
  ])
  ...
}
```

`logging.logWriter`がないと、Ops Agentを入れてもCloud Loggingに何も届かない。

## 前提

- Terraform 1.10以上、`hashicorp/google` 7.x
- `gcloud`認証済み、対象プロジェクトで課金が有効
- 有効化するAPI: `compute` / `iap` / `logging` / `monitoring`

## 実行

```bash
cp terraform.tfvars.example terraform.tfvars
# project_id と iap_member を自分の値に書き換える
terraform init
terraform apply
```

`terraform apply`だけで完結する。playbookは`google_storage_bucket_object`でアップロードされ、`depends_on`でVMより先に置かれる。

## 検証環境

```
Terraform v1.14.5
provider registry.terraform.io/hashicorp/google v7.46.0
Debian 12、ansible-core（apt）、nginx 1.22、Ops Agent
```

## 検証結果

### 1. startup-script は「初回bootのみ」ではない

GCEのstartup scriptは**毎回のbootで実行される**。

```console
$ sudo wc -l < /var/log/startup-ansible.log   # 再起動前
209

$ gcloud compute instances reset tf-adv-gce-ans-web --zone=asia-northeast1-a

$ sudo wc -l < /var/log/startup-ansible.log   # 再起動後
257

$ sudo grep -c "startup-ansible: BEGIN" /var/log/startup-ansible.log
4
```

`BEGIN`が4回。bootのたびに走っている。

これは運用上ありがたい。GCSのplaybookを更新してVMを再起動すれば、設定が反映される。VMを作り直す必要はない。

ただし**毎回`apt-get install ansible`が走る**ので、boot時間は延びる。本番なら、Ansibleが入っているカスタムイメージを使うか、条件分岐を入れる。

### 2. Terraformの「成功」は中身を保証しない

検証の途中で実際に起きた。

```console
$ terraform apply
Apply complete! Resources: 35 added, 0 changed, 0 destroyed.
```

VMの中では失敗していた。

```console
$ sudo tail /var/log/startup-ansible.log
ERROR! the role 'common' was not found in /opt/ansible/playbooks/roles:...
```

原因はAnsibleのrole探索。**playbookのあるディレクトリを基準に探す。** `playbooks/site.yml`から見ると`playbooks/roles/`を見に行くが、roleは`roles/`にある。

```ini
# ansible.cfg
[defaults]
roles_path = ./roles
```

`terraform state list`は35件のまま、`terraform plan`も差分なし。**Terraformから見て、この失敗は存在しない。**

startup scriptの終了コードはVMの状態に影響しない。設定が終わったかどうかは、VMの中を見るしかない。

### 3. template の validate には %s が要る

nginxの設定を書く前に構文検査したい。`template`モジュールに`validate`がある。

```yaml
validate: nginx -t -c /etc/nginx/nginx.conf   # これは動かない
```

```text
fatal: [localhost]: FAILED! => {"msg": "validate must contain %s: nginx -t -c ..."}
```

`%s`に一時ファイルのパスが入る。ただし**サイトのフラグメントには使えない。** `nginx -t -c %s`は完全な`nginx.conf`を期待するので、`server { ... }`だけのファイルでは必ず失敗する。

書いてから検査し、失敗したら戻す形にした。

```yaml
- name: Deploy the site configuration
  ansible.builtin.template:
    dest: /etc/nginx/sites-available/default
    backup: true
  register: nginx_site
  notify: reload nginx

- name: Verify the configuration parses, restoring the backup if it does not
  block:
    - ansible.builtin.command: nginx -t
      changed_when: false
  rescue:
    - ansible.builtin.copy:
        src: "{{ nginx_site.backup_file }}"
        dest: /etc/nginx/sites-available/default
        remote_src: true
    - ansible.builtin.fail:
        msg: "nginx の設定が不正だったため、直前のバックアップに戻した"
```

タスクが失敗するとハンドラは走らない。**壊れた設定がreloadされることはない。**

### 4. 冪等性

2回目は何も変えない。

```console
localhost : ok=22  changed=0  unreachable=0  failed=0  skipped=4  rescued=0  ignored=0
```

Ops Agentのインストーラは冪等ではないので、`stat`で導入済みを判定してスキップしている。これがないと毎回`changed`になる。

### 5. サービスの妥当性

動いていることと、正しいことは別。3つを見る。

```console
$ sudo nginx -t
nginx: configuration file /etc/nginx/nginx.conf test is successful

$ for s in nginx google-cloud-ops-agent; do
    echo "$s: enabled=$(systemctl is-enabled $s) active=$(systemctl is-active $s)"
  done
nginx: enabled=enabled active=active
google-cloud-ops-agent: enabled=enabled active=active
```

`is-enabled`が`enabled`でないと、再起動後に上がらない。playbookの中でも同じ検査をして、満たさなければ失敗するようにしてある。

### 6. curl で疎通を確かめる

2経路で見る。

**VM内から。**

```console
$ curl -s http://127.0.0.1/ | grep -o "tf-adv-ansible-nginx"
tf-adv-ansible-nginx

$ curl -s -w " (%{http_code})\n" http://127.0.0.1/healthz
ok (200)
```

200が返るだけでなく、配置した内容が出ていることまで見る。Ansibleの中でも`uri`モジュールで本文にマーカーが含まれるかを検査している。

**IAPトンネル経由。VMに外部IPはない。**

```console
$ gcloud compute start-iap-tunnel tf-adv-gce-ans-web 80 \
    --local-host-port=localhost:18080 --zone=asia-northeast1-a &

$ curl -s -o /dev/null -w "index: %{http_code}\n" http://localhost:18080/
index: 200

$ curl -s http://localhost:18080/healthz
ok

$ curl -s http://localhost:18080/ | grep -o "configured by Ansible"
configured by Ansible
```

ファイアウォールとネットワーク経路まで通っていることが分かる。インターネットには一切出していない。

### 7. 再起動後もサービスが上がる

```console
$ gcloud compute instances reset tf-adv-gce-ans-web --zone=asia-northeast1-a
（80秒待つ）

$ for s in nginx google-cloud-ops-agent; do echo "$s: $(systemctl is-active $s)"; done
nginx: active
google-cloud-ops-agent: active

$ curl -s -w " healthz(%{http_code})\n" http://127.0.0.1/healthz
ok healthz(200)
```

### 8. 設定変更は reload で反映され、プロセスは落ちない

`nginx_body`を変えて再実行する。

```console
localhost : ok=22  changed=1  ...

MainPID before=2038 after=2038

$ curl -s http://127.0.0.1/ | grep -o "reloaded without restart"
reloaded without restart
```

`MainPID`が変わっていない。`systemd`の`reloaded`はプロセスを落とさずに設定を読み直す。接続中のリクエストは切れない。

ハンドラを`restart`にするとPIDが変わる。**`reload`で足りるものを`restart`にしない。**

## Cloud Loggingに残るもの

### Ops Agent を入れるまで何も来ない

これがGKEとの最大の違い。GKEは収集エージェントがコンテナの標準出力を自動で拾うが、**GCEはOps Agentを入れるまでVMのログは1件も届かない。**

導入後。

```console
syslog                   5件
nginx_access             5件
nginx_error              1件
ops-agent-fluent-bit     5件
```

| ログ | クエリ |
|---|---|
| syslog | `logName="projects/PROJECT_ID/logs/syslog"` |
| nginxアクセスログ | `logName="projects/PROJECT_ID/logs/nginx_access"` |
| nginxエラーログ | `logName="projects/PROJECT_ID/logs/nginx_error"` |
| Ops Agent自身 | `logName="projects/PROJECT_ID/logs/ops-agent-fluent-bit"` |

**`logName`はreceiver名になる。** `config.yaml`で付けた名前がそのまま出る。

```yaml
logging:
  receivers:
    nginx_access:          # ← この名前が logName になる
      type: files
      include_paths:
        - /var/log/nginx/access.log
```

`files`レシーバが読んだ行は`jsonPayload.message`に入る。`textPayload`ではない。

### startup script のログは Cloud Logging に来ない

```console
$ gcloud logging read 'resource.type="gce_instance" AND logName=~"startupscript"' --limit=5
（0件）
```

Ops Agentを入れる前に走るので当然だが、**構築の失敗がいちばん起きやすいのがこの区間**でもある。シリアルコンソールかVM内の`/var/log/startup-ansible.log`を見る。

## 後片付け

```console
$ terraform destroy
Destroy complete! Resources: 35 destroyed.
```

バケットは`force_destroy = true`にしてある。startup scriptが書き込んだあとでも消せる。

## まとめ

- **startup scriptは毎回のbootで実行される。** 「初回のみ」ではない。playbookを更新してVMを再起動すれば反映される
- **Terraformの「成功」は中の設定を保証しない。** Ansibleが失敗しても`terraform plan`は差分なしのまま
- Ansibleのrole探索はplaybookのディレクトリ基準。`roles_path`が要る
- **`template`の`validate`は`%s`が必須で、設定フラグメントには使えない。** `backup` → `nginx -t` → 失敗時に`rescue`で復元
- **動いていることと正しいことは別。** `is-active`だけでなく`is-enabled`と構文検査も見る
- **curlは200だけでなく中身も見る。** 外部IPなしならIAPトンネルで外からも確かめられる
- **`reload`ならプロセスは落ちない。** `MainPID`が変わらないことで確認できる
- **GCEはOps Agentを入れるまでログが1件も来ない。** GKEとは前提が違う

## 参考資料

- [Google Cloud: Startup scripts on Linux VMs](https://cloud.google.com/compute/docs/instances/startup-scripts/linux)
- [Google Cloud: Ops Agent configuration](https://cloud.google.com/logging/docs/agent/ops-agent/configuration)
- [Google Cloud: Using IAP for TCP forwarding](https://cloud.google.com/iap/docs/using-tcp-forwarding)
- [Ansible: template module](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/template_module.html)
- [Ansible: Blocks（rescue）](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_blocks.html)
