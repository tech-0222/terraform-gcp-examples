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

既定のCompute Engine SAは使わない。権限は[組織ポリシーと付与済みのロールで変わる](https://cloud.google.com/compute/docs/access/service-accounts)が、用途ごとに分けるため専用のSAを作る。

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

`vm.tf`は`debian-12`イメージファミリーを参照し、Ops Agentもバージョンを固定していない。**検証日・イメージ名・各エージェントのバージョンを記録していないので、ログ収集の結果を現行環境にそのまま一般化しないこと。** 再検証するなら`ansible --version`と`dpkg-query -W ansible ansible-core nginx google-guest-agent google-cloud-ops-agent`の出力も残す。

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

行数が209から257に増え、`BEGIN`は累計4回。[startup scriptは起動のたびに実行される](https://docs.cloud.google.com/compute/docs/instances/startup-scripts/linux)という仕様とは整合するが、**この出力だけでは各bootとの対応までは取れていない。** 確かめるなら再起動の前後で`BEGIN`の件数と時刻、`/proc/sys/kernel/random/boot_id`を記録する。

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

startup scriptの終了コードはVMの状態に影響しない。設定が終わったかどうかは、VM内のログやシリアルポート出力で別途確認する。

### 3. template の validate には %s が要る

nginxの設定を書く前に構文検査したい。`template`モジュールに`validate`がある。

```yaml
validate: nginx -t -c /etc/nginx/nginx.conf   # これは動かない
```

```text
fatal: [localhost]: FAILED! => {"msg": "validate must contain %s: nginx -t -c ..."}
```

`%s`に一時ファイルのパスが入る。ただし`nginx -t -c %s`に**フラグメントをそのまま渡すことはできない。** `nginx -t -c`は完全な`nginx.conf`を期待するので、`server { ... }`だけのファイルでは失敗する。

[`validate`には任意のコマンドを指定できる](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/template_module.html)ので、フラグメントを`http`コンテキストに組み込む検証スクリプトを呼べば、配備前の検査もできる。今回はそこまでせず、配備後に検査して失敗したらバックアップから戻す方式にした。

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
      when: nginx_site.backup_file is defined
    - ansible.builtin.fail:
        msg: "nginx の設定が不正だったため、直前のバックアップに戻した"
```

`when` を落とさないこと。[`backup_file` が返るのは実際にバックアップを取ったときだけ](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/copy_module.html#return-values)で、構文検査は無変更の回も走る。**バックアップが無い回に失敗すると、復元タスクが未定義変数で落ちる。**

タスクが失敗するとハンドラは走らない。**壊れた設定がreloadされることはない。**

### 4. 冪等性

2回目は何も変えない。

```console
localhost : ok=22  changed=0  unreachable=0  failed=0  skipped=4  rescued=0  ignored=0
```

インストーラを呼ぶのは`ansible.builtin.command`で、`changed_when`を指定していない。[このモジュールはスキップされない限り実状態を調べずに`changed`を返す](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/command_module.html)ので、`stat`で`/etc/google-cloud-ops-agent`の有無を見て再実行を省いている。

**確かめたのは「2回目のplaybookが`changed=0`になる」ことまで。** インストーラ自体が冪等かどうかは判定していない。

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

HTTP検査は**ステータスと本文の両方**を見る。

```yaml
failed_when: >-
  nginx_local.status != 200
  or nginx_marker not in (nginx_local.content | default(''))
```

`failed_when`はモジュール自身のステータス判定を**置き換える**ので、前半が無いとマーカーを含むエラーページが素通りする。後半の`default('')`は、接続できず`content`が未定義のときに式ごと落ちるのを防ぐため。

nginx と Ops Agent は明示的に自動起動させる設計なので、`is-enabled`も検査する。playbookでも同じことを見て、満たさなければ失敗する。**ただし許可する出力は揃えていない。** nginxは`enabled`のみ、Ops Agentは`enabled`と`generated`を許容している。

ただし`systemd`には`static`のように明示的な有効化を要さないユニットもあり、この条件をすべてのサービスに当てはめることはできない。

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

### 8. HTMLの変更は再起動なしで反映される

ローカルの`ansible/roles/nginx/defaults/main.yml`で`nginx_body`を変え、`terraform apply`でGCSの資材を更新する。次に`terraform output -raw rerun_playbook_example`が表示するコマンドで、既存VMへの同期とplaybookの再実行を行う。**VMは再起動しない。**

**この変数は`index.html.j2`だけが参照しており、`notify: reload nginx`が付いているのはサイト設定の配備タスクのほうなので、この変更ではハンドラは走らない。**

```console
localhost : ok=22  changed=1  ...

MainPID before=2038 after=2038

$ curl -s http://127.0.0.1/ | grep -o "reloaded without restart"
reloaded without restart
```

`MainPID`が変わっていない。**この回で確認できたのは、HTMLの差し替えにプロセスの再起動が要らないことまで。**

サイト設定を変えた場合は`reload`ハンドラに通知される。[nginxの`reload`](https://nginx.org/en/docs/control.html)はmasterプロセスを残して新しいworkerを起動し、古いworkerは処理中のリクエストを終えてから終了する。**その挙動はこの検証では切り分けていない。**

**検査の前にハンドラを流している。** ハンドラは[既定でrole/tasksの実行後にまとめて走る](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_handlers.html)ので、そのままではHTTP検査が`reload`より前に実行され、**変更前の設定を検査してしまう。** `nginx_port`を変えるとさらに悪く、新しいポートへの検査が`reload`前に失敗し、[失敗したホストではハンドラも走らない](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_error_handling.html)。

```yaml
- name: Apply any pending reload before verifying
  ansible.builtin.meta: flush_handlers
```

ハンドラを`restart`にするとPIDが変わる。**`reload`で足りるものを`restart`にしない。**

## Cloud Loggingに残るもの

### Ops Agent を入れるまでOS・アプリケーションのログが来ない

これがGKEとの最大の違い。GKEは収集エージェントがコンテナの標準出力を自動で拾うが、**今回の構成ではOps Agentを入れるまで、ゲストOSやnginxのログが1件も届かなかった。**

VMの作成や`reset`を記録する[Cloud Audit Logs](https://docs.cloud.google.com/compute/docs/logging/audit-logging)はこれとは別で、Ops Agentが無くても残る。ここで言っているのはOS・アプリケーション側のログのこと。

ただしOps Agentが唯一の経路ではない。[シリアルポート出力をCloud Loggingへ送る機能](https://cloud.google.com/compute/docs/troubleshooting/viewing-serial-port-output)もある（既定は無効。`serial-port-logging-enable`メタデータで有効化）。

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

**`logName`のログID部分がreceiver IDになる。** `files`レシーバなら`projects/PROJECT_ID/logs/RECEIVER_ID`で、`nginx_access`なら`projects/PROJECT_ID/logs/nginx_access`。[レシーバの型によっては入力タグが後ろに付く](https://docs.cloud.google.com/logging/docs/agent/ops-agent/configuration)ので、この形がすべてではない。

```yaml
logging:
  receivers:
    nginx_access:          # ← この名前が logName になる
      type: files
      include_paths:
        - /var/log/nginx/access.log
```

`files`レシーバが読んだ行は`jsonPayload.message`に入る。`textPayload`ではない。

### startupscript を含む logName ではログを確認できなかった

```console
$ gcloud logging read 'resource.type="gce_instance" AND logName=~"startupscript"' --limit=5
（0件）
```

**この検索で分かったのは、`logName`に`startupscript`を含むログが0件だったことまで。** 原因は特定していない。今回の`config.yaml`は`/var/log/startup-ansible.log`を収集していないので、収集していないのか実行時期の問題なのかを切り分けていない。切り分けるなら`logName`の条件を外し、instance_idと時間帯で絞って`startup-ansible: BEGIN`を探す。

いずれにせよ、**構築の失敗がいちばん起きやすいのはこの区間**なので、シリアルコンソールかVM内の`/var/log/startup-ansible.log`を見る。

## 後片付け

```console
$ terraform destroy
Destroy complete! Resources: 35 destroyed.
```

バケットは`force_destroy = true`にしてある。資材のアップロードはTerraformが行い、startup scriptはGCSから読むだけ。

## まとめ

- **startup scriptは毎回のbootで実行される。** 「初回のみ」ではない。playbookを更新してVMを再起動すれば反映される
- **Terraformの「成功」は中の設定を保証しない。** Ansibleが失敗しても`terraform plan`は差分なしのまま
- Ansibleのrole探索は[playbookと同じ階層の`roles/`が既定](https://docs.ansible.com/projects/ansible-core/devel/playbook_guide/playbooks_reuse_roles.html)。今回の配置では`roles_path`の追加が要った
- **`template`の`validate`は`%s`が必須。** フラグメントを`nginx -t -c %s`へ直接は渡せない。今回は `backup` → `nginx -t` → 失敗時に`rescue`で復元
- **動いていることと正しいことは別。** `is-active`だけでなく`is-enabled`と構文検査も見る
- **curlは200だけでなく中身も見る。** 外部IPなしならIAPトンネルで外からも確かめられる
- **HTMLの差し替えにプロセスの再起動は要らない。** `MainPID`が変わらないことで確認できる。`reload`そのものの挙動は切り分けていない
- **GCEは、今回の構成ではOps Agentを入れるまでログが1件も来なかった。** GKEとは前提が違う。シリアルポート出力を送る経路は別にある

## 参考資料

- [Google Cloud: Startup scripts on Linux VMs](https://cloud.google.com/compute/docs/instances/startup-scripts/linux)
- [Google Cloud: Ops Agent configuration](https://cloud.google.com/logging/docs/agent/ops-agent/configuration)
- [Google Cloud: Using IAP for TCP forwarding](https://cloud.google.com/iap/docs/using-tcp-forwarding)
- [Ansible: template module](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/template_module.html)
- [Ansible: Blocks（rescue）](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_blocks.html)
