# 24. GKEのログはどんな形でCloud Loggingに届くか

GKEのPodが標準出力に書いた行は、そのままCloud Loggingに入るわけではない。GKEの収集エージェントが解釈を加える。

- 素のテキストなのかJSONなのかで、入るフィールドが変わる
- JSONの中に`severity`があると、エントリの`severity`に昇格する
- 複数行のスタックトレースは1エントリにまとまらない

Fluentdをサイドカーに置く構成もよく使われるが、**何が増えて何が失われるのか**は測ってみないと分からない。この例では、サイドカーなしとありを同じクラスタに並べて比べる。

## 構成

| リソース | 用途 |
|---|---|
| VPC + サブネット2つ + Cloud NAT | GKEノードと踏み台。外部IPなし |
| 踏み台VM | プライベートエンドポイントのGKEへ到達する唯一の経路 |
| GKEクラスタ（Standard、ゾーナル、プライベート） | `logging_config`で`WORKLOADS`を明示 |

```hcl
logging_config {
  enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
}
```

これは既定値だが明示している。**サイドカーなしでもコンテナの標準出力がCloud Loggingへ届く理由**がここにあり、サイドカーと比較する土台になるため。

## 3つの経路を並べる

| マニフェスト | 経路 | 何を見るか |
|---|---|---|
| `k8s/01-plain-stdout.yaml` | アプリ → 収集エージェント | 素のテキスト / JSON / `severity`付きJSONの3形 |
| `k8s/03-fluentd-sidecar.yaml` | アプリ → ファイル → Fluentd → 標準出力 → エージェント | **2ホップ**。Fluentdが足したもの・失ったもの |
| `k8s/04-multiline.yaml` | アプリ → エージェント | Javaスタックトレースが分割されるか |

`fluent.conf`（`k8s/02-fluentd-config.yaml`）の各ディレクティブは、それぞれ1つの問いに対応させている。

```
tag app.log          → tag はエントリのどこかに現れるか
record_transformer   → 足したキーは jsonPayload のキーになるか
severity ERROR       → エントリの severity に昇格するか
@type stdout / json  → サイドカー自身の標準出力を、さらにエージェントが拾う
```

アプリとFluentdは`resource.labels.container_name`で分かれるので、突き合わせられる。

## 前提

- Terraform 1.10以上、`hashicorp/google` 7.x
- `gcloud`認証済み、対象プロジェクトで課金が有効
- 有効化するAPI: `compute.googleapis.com`、`container.googleapis.com`

## 実行

```bash
cp terraform.tfvars.example terraform.tfvars
# project_id と iap_member を自分の値に書き換える
terraform init
terraform apply

# 踏み台から
kubectl apply -f k8s/01-plain-stdout.yaml -f k8s/02-fluentd-config.yaml \
              -f k8s/03-fluentd-sidecar.yaml -f k8s/04-multiline.yaml
```

## 検証環境

```
Terraform v1.14.5
provider registry.terraform.io/hashicorp/google v7.46.0
GKE 1.35.7-gke.1027000（REGULARチャンネル）
fluentd v1.16-debian-1
```

## 検証結果

### 1. 素のテキストは textPayload に入る

```console
$ gcloud logging read '... AND textPayload:"PLAIN"' --format="value(severity,textPayload)"
INFO	PLAIN this is an ordinary line
```

`severity`は`INFO`。指定していないので既定値が入る。

`logName`は`projects/PROJECT_ID/logs/stdout`。**標準出力かどうかで決まり、アプリ名やtagは入らない。**

### 2. JSON行は jsonPayload に自動で構造化される

サイドカーは無い。アプリが標準出力にJSONを1行書いただけ。

```console
$ gcloud logging read '... AND jsonPayload.msg:"JSON"' --format="value(severity,jsonPayload)"
ERROR	msg=JSON with severity;order_id=1235
INFO	msg=JSON without severity;order_id=1234
```

**GKEの収集エージェントがJSONを解釈している。** 構造化ログを出すだけなら、Fluentdサイドカーは要らない。

### 3. JSON内の severity はエントリに昇格し、jsonPayloadから消える

上の出力をJSONで見る。

```json
{ "severity": "ERROR",
  "jsonPayload": { "msg": "JSON with severity", "order_id": 1235 } }
```

アプリが書いたのは`{"severity":"ERROR","msg":"JSON with severity","order_id":1235}`。**`severity`キーは`jsonPayload`に残らず、エントリの`severity`になっている。**

指定しなかった側は`INFO`のままで、`jsonPayload`は`{"msg":..., "order_id":1234}`。

### 4. Fluentdが足したキーは jsonPayload のキーになる

```console
$ gcloud logging read '... AND resource.labels.container_name="fluentd"' \
    --format="value(severity,jsonPayload)"
ERROR	env=verification;fluentd_tag=app.log;message={"msg":"APP json line to file","order_id":2345};service=order-api
```

`record_transformer`で足した`service` / `env` / `fluentd_tag`が、そのまま`jsonPayload`のキーになっている。

**`severity ERROR`も昇格した。** サイドカーは自分の標準出力にJSONを書いているだけだが、それを拾うエージェントが同じ解釈をしている。2ホップでも扱いは変わらない。

### 5. tag は自動では現れない

```console
$ gcloud logging read '...' --format="value(logName)" | sort -u
projects/PROJECT_ID/logs/stdout
```

`logName`は`stdout`のまま。Fluentdの`tag app.log`はどこにも出ない。

上の出力に`fluentd_tag=app.log`があるのは、`record_transformer`で`fluentd_tag ${tag}`と**明示的に入れたから**。入れなければtagは失われる。

### 6. サイドカーを挟むと構造が1段深くなる

これが一番効く。

```json
{
  "env": "verification",
  "fluentd_tag": "app.log",
  "service": "order-api",
  "message": "{\"msg\":\"APP json line to file\",\"order_id\":2345}"
}
```

アプリが書いたJSONが、**文字列のまま`message`に入っている。** `order_id`で検索することはできない。

原因は`fluent.conf`の`<parse> @type none`。Fluentdは行を解釈せず、生のテキストとして`message`に詰める。

```
<source>
  @type tail
  <parse>
    @type none      ← ここ
  </parse>
</source>
```

**サイドカーは何もしなければ構造を失わせる。** アプリがすでにJSONを出しているなら、`@type json`にするか、そもそもサイドカーを挟まないほうが良い。

### 7. 複数行は1行ずつ別エントリになる

```console
$ gcloud logging read '... AND labels."k8s-pod/app"="multiline"' --format="value(textPayload)"
MULTILINE-END
MULTILINE-START java.lang.NullPointerException: order is null
	at com.example.OrderService.process(OrderService.java:42)
	at com.example.OrderController.post(OrderController.java:18)
MULTILINE-END
```

スタックトレースが行ごとに分かれている。コンソールで見ると、他のPodのログに挟まれてバラバラに並ぶ。

まとめたい場合は、アプリ側でJSON 1行にするか、Fluentdに`multiline`パーサを入れる。

## Cloud Loggingに残るもの

| ログ | クエリ | 内容 |
|---|---|---|
| コンテナの標準出力 | `resource.type="k8s_container" AND resource.labels.container_name="NAME"` | `textPayload` または `jsonPayload`。`container_name`でアプリとサイドカーが分かれる |
| GKE監査ログ | `protoPayload.serviceName="container.googleapis.com"` | クラスタの作成・更新 |

Podのラベルは`labels."k8s-pod/<label>"`で絞り込める。`labels."k8s-pod/app"="plain-stdout"`のように使う。

## 後片付け

```console
$ terraform destroy
Destroy complete! Resources: 22 destroyed.
```

GKE・踏み台VM・Cloud NATは利用中に料金が発生する。Cloud Loggingの取り込みにも課金がある。

## まとめ

- **素のテキストは`textPayload`、JSONは`jsonPayload`。** 収集エージェントが判別する
- **JSON内の`severity`はエントリに昇格し、`jsonPayload`からは消える**
- **構造化ログを出すだけならFluentdサイドカーは要らない**
- Fluentdが`record_transformer`で足したキーは`jsonPayload`のキーになる。`severity`も昇格する
- **tagは自動では現れない。** `${tag}`をレコードに入れて初めて見える
- **サイドカーは何もしなければ構造を失わせる。** `@type none`だとアプリのJSONが文字列として`message`に入る
- **複数行は1行ずつ別エントリになる。** スタックトレースはまとまらない

## 参考資料

- [Google Cloud: About logging in GKE](https://cloud.google.com/kubernetes-engine/docs/concepts/about-logs)
- [Google Cloud: Configure logging for GKE](https://cloud.google.com/kubernetes-engine/docs/how-to/configure-logging)
- [Google Cloud: Structured logging](https://cloud.google.com/logging/docs/structured-logging)
- [Fluentd: record_transformer filter](https://docs.fluentd.org/filter/record_transformer)
- [Terraform Registry: google_container_cluster](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_cluster)
