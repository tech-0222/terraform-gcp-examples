# 25 - リソースパラメータ対応

このファイルは**TerraformとAnsibleの受け渡し**について対応づけます。自動生成の`docs/PARAMETER.md`とは別物です。

一次情報:

- [Google Cloud: Startup scripts on Linux VMs](https://cloud.google.com/compute/docs/instances/startup-scripts/linux)
- [Google Cloud: Ops Agent configuration](https://cloud.google.com/logging/docs/agent/ops-agent/configuration)
- [Ansible: template module](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/template_module.html)

## 確認コマンド

```bash
# startup script が何回走ったか
gcloud compute ssh VM --zone=ZONE --tunnel-through-iap \
  --command='sudo grep -c "startup-ansible: BEGIN" /var/log/startup-ansible.log'

# サービスの妥当性
gcloud compute ssh VM --zone=ZONE --tunnel-through-iap \
  --command='sudo nginx -t; systemctl is-enabled nginx; systemctl is-active nginx'

# 外部IPなしのVMへ外からcurl
gcloud compute start-iap-tunnel VM 80 --local-host-port=localhost:18080 --zone=ZONE &
curl -s http://localhost:18080/healthz
```

## ネットワーク

| 項目 | 本サンプル | 備考 |
|---|---|---|
| Subnet | `10.50.0.0/24` | 外部IPなし |
| Cloud NAT | 有効 | apt と Ops Agent インストーラの取得に要る |
| FW: SSH | `35.235.240.0/20` → 22 | IAP |
| FW: HTTP | `35.235.240.0/20` → 80 | **IAPトンネルでcurlするために要る** |

## google_service_account（新規作成）

| 項目 | 本サンプル | 区分 | 備考 |
|---|---|---|---|
| SA | 専用に作成 | 明示 | Compute Engineの既定SAは使わない |
| GCS読み取り | `roles/storage.objectViewer` | 明示 | **バケット単位**。プロジェクト全体には付けない |
| ログ送信 | `roles/logging.logWriter` | 明示 | **これがないとOps Agentを入れてもログが届かない** |
| メトリクス送信 | `roles/monitoring.metricWriter` | 明示 | |

## google_compute_instance

| 項目 | 本サンプル | 区分 | 備考 |
|---|---|---|---|
| 外部IP | なし | 意図的に省略 | `network_interface`に`access_config`を書かない |
| `metadata_startup_script` | GCS同期 + ansible-playbook | 明示 | **毎回のbootで実行される。初回のみではない** |
| `depends_on` | バケットオブジェクト・IAM・NAT | 明示 | **Terraformが推論できない順序依存**。startup scriptがGCSを読むことをTerraformは知らない |

## google_storage_bucket_object

| 項目 | 本サンプル | 備考 |
|---|---|---|
| `for_each` | `fileset(".../ansible", "**")` | roleファイルを足してもTerraformの変更が不要 |
| `detect_md5hash` | `filemd5(...)` | 変更したファイルが差し替わる。`terraform apply`でplaybookを配れる |

## Ansible

| 項目 | 本サンプル | 備考 |
|---|---|---|
| `roles_path` | `./roles` | **これがないとroleが見つからない**。探索はplaybookのディレクトリ基準 |
| `template` の検査 | `backup` → `nginx -t` → `rescue`で復元 | `validate`は`%s`必須で、設定フラグメントには使えない |
| ハンドラ | `reload`（restartではない） | プロセスを落とさない |
| Ops Agent導入 | `stat`で導入済みを判定 | インストーラが冪等でないため |

## 実測で確認した挙動

| 項目 | 結果 | 備考 |
|---|---|---|
| startup script の実行回数 | **毎回のboot** | `BEGIN`が4回。209→257行に増えた |
| Ansible失敗時のTerraform | **成功のまま** | `35 added`と出た一方でroleが見つからず失敗 |
| `template` の `validate` | `%s`が必須 | `validate must contain %s` |
| 冪等性 | 2回目は`changed=0` | `ok=22 changed=0 failed=0` |
| サービスの妥当性 | 両方 `enabled` / `active` | `nginx -t` も成功 |
| curl（VM内） | index 200、healthz `ok` | 本文のマーカーまで確認 |
| curl（IAPトンネル） | **外部IPなしで200** | ファイアウォールと経路まで検証できる |
| 再起動後 | 両サービス `active` | healthz 200 |
| 設定変更の反映 | `reload`で反映、**MainPIDは不変** | `2038` → `2038` |

## Cloud Loggingに残るもの

| ログ | クエリ | 内容 |
|---|---|---|
| syslog | `logName="projects/PROJECT/logs/syslog"` | Ops Agent の既定パイプライン |
| nginxアクセス | `logName="projects/PROJECT/logs/nginx_access"` | **logName は receiver 名になる** |
| nginxエラー | `logName="projects/PROJECT/logs/nginx_error"` | 同上 |
| Ops Agent自身 | `logName="projects/PROJECT/logs/ops-agent-fluent-bit"` | 自己診断 |

**Ops Agent を入れるまでVMのログは1件も届かない。** GKE（収集エージェントが標準出力を自動で拾う）とは前提が違う。

`files`レシーバが読んだ行は`jsonPayload.message`に入る。`textPayload`ではない。

**startup script のログはCloud Loggingに来ない**（0件）。Ops Agent導入前に走るため。構築失敗が最も起きやすい区間なので、シリアルコンソールかVM内の`/var/log/startup-ansible.log`を見る。

未指定（デフォルト）の項目はコンソール/APIのデフォルト値に従う。推測での記載はしない。
