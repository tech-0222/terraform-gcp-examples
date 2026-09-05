# 24 - リソースパラメータ対応

このファイルは**GKEのログがCloud Loggingにどう届くか**について対応づけます。自動生成の`docs/PARAMETER.md`とは別物です。VPC/踏み台の基本部分は`11-gke-private-bastion`と同じ構成のため、ここでは差分を中心に記載します。

一次情報:

- [Google Cloud: About logging in GKE](https://cloud.google.com/kubernetes-engine/docs/concepts/about-logs)
- [Google Cloud: Structured logging](https://cloud.google.com/logging/docs/structured-logging)
- [Fluentd: record_transformer filter](https://docs.fluentd.org/filter/record_transformer)

## 確認コマンド

```bash
gcloud logging read 'resource.type="k8s_container" AND resource.labels.cluster_name="CLUSTER" AND resource.labels.container_name="app"' \
  --limit=5 --freshness=1h --format=json
```

Podのラベルで絞る場合は `labels."k8s-pod/app"="NAME"` を足します。

## google_container_cluster（差分）

| 項目 | 本サンプル | 区分 | Terraform | 備考 |
|---|---|---|---|---|
| ログ収集 | `SYSTEM_COMPONENTS,WORKLOADS` | 明示 | `logging_config.enable_components` | 既定値。**サイドカーなしでも標準出力が届く理由**なので明示した |

## Kubernetesリソース（Terraform管理外）

| ファイル | 経路 | 見るもの |
|---|---|---|
| `k8s/01-plain-stdout.yaml` | アプリ → エージェント | 素のテキスト / JSON / `severity`付きJSON |
| `k8s/02-fluentd-config.yaml` | — | `fluent.conf`。各ディレクティブが1つの問いに対応 |
| `k8s/03-fluentd-sidecar.yaml` | アプリ → ファイル → Fluentd → 標準出力 → エージェント | 2ホップで何が増え、何が失われるか |
| `k8s/04-multiline.yaml` | アプリ → エージェント | スタックトレースが分割されるか |

## fluent.conf と Cloud Logging の対応

| fluent.conf | Cloud Logging での現れ方 |
|---|---|
| `tag app.log` | **現れない。** `logName`は`.../logs/stdout`のまま |
| `record_transformer` で足したキー | `jsonPayload` のキーになる |
| `severity ERROR` | エントリの `severity` に**昇格する** |
| `<parse> @type none` | 元の行が**文字列のまま** `message` に入る |

## 実測で確認した挙動

| 項目 | 結果 | 備考 |
|---|---|---|
| 素のテキスト | `textPayload` | `severity` は `INFO`（既定） |
| JSON行（サイドカーなし） | **`jsonPayload` に自動構造化** | 収集エージェントが解釈する。サイドカー不要 |
| JSON内の `severity` | エントリに昇格し、`jsonPayload` から消える | `ERROR` で確認 |
| Fluentd の `record_transformer` | `jsonPayload` のキーになる | `service` / `env` / `fluentd_tag` |
| Fluentd の `severity` | **昇格する** | 標準出力に書いていても扱いは同じ |
| Fluentd の `tag` | **自動では現れない** | `${tag}` を明示して初めて見える |
| サイドカー経由のJSON | **文字列のまま `message` に入る** | `@type none` のため。`order_id` で検索できない |
| 複数行 | **1行ずつ別エントリ** | スタックトレースはまとまらない |

## Cloud Loggingに残るもの

| ログ | クエリ | 内容 |
|---|---|---|
| コンテナの標準出力 | `resource.type="k8s_container" AND resource.labels.container_name="NAME"` | `textPayload` または `jsonPayload` |
| GKE監査ログ | `protoPayload.serviceName="container.googleapis.com"` | クラスタの作成・更新 |

未指定（デフォルト）の項目はコンソール/APIのデフォルト値に従う。推測での記載はしない。
