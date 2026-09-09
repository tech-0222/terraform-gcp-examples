# 24. GKEのログはどんな形でCloud Loggingに届くか

GKEのPodが標準出力に書いた行は、そのままCloud Loggingに入るわけではない。GKEの収集エージェントが解釈を加える。

- 素のテキストなのかJSONなのかで、入るフィールドが変わる
- JSONの中に`severity`があると、エントリの`severity`に昇格する
- 複数行のスタックトレースがどう入るかは、保存した結果からは判別できなかった

Fluentdをサイドカーに置く構成もよく使われるが、**何が増えて何が失われるのか**は測ってみないと分からない。この例では、サイドカーなしとありを同じクラスタに並べて比べる。

## 構成

| リソース | 用途 |
|---|---|
| VPC + サブネット2つ + Cloud NAT | GKEノードと踏み台。外部IPなし |
| 踏み台VM | GKEのプライベートエンドポイントへ`kubectl`を通す。承認済みネットワークに踏み台サブネットを登録しているが、**内部エンドポイントへの適用は有効化していない**（`enable-authorized-networks-on-private-endpoint`相当。[ネットワーク分離](https://docs.cloud.google.com/kubernetes-engine/docs/how-to/latest/network-isolation)） |
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

アプリとFluentdは`resource.labels.container_name`で分かれる。ただし`03-fluentd-sidecar.yaml`のアプリは両方の行を`/var/log/app/app.log`に落としており標準出力に何も出さないので、Cloud Loggingに出るのは`fluentd`だけ。加工前を見るなら`kubectl exec deployment/fluentd-sidecar -c app -- cat /var/log/app/app.log`。

## 前提

- Terraform 1.10以上、`hashicorp/google` 7.x
- 対象プロジェクトで課金が有効
- 有効化するAPI: `compute.googleapis.com`、`container.googleapis.com`、`iap.googleapis.com`
- `provider.tf`は認証情報を指定していないのでADCを使う。ローカルで実行するなら`gcloud auth application-default login`（Cloud Shellでは不要）
- `iap_member`に指定するユーザーは、踏み台のサービスアカウントに対する`roles/iam.serviceAccountUser`が要る。[サービスアカウントの付いたVMへ接続する全ユーザーに必要](https://docs.cloud.google.com/compute/docs/oslogin/set-up-oslogin)で、**このTerraformでは付与しない**

## 実行

```bash
cp terraform.tfvars.example terraform.tfvars
# project_id と iap_member を自分の値に書き換える
terraform init
terraform apply
```

踏み台の起動スクリプトはパッケージを入れるだけで、マニフェストもkubeconfigも用意しない。転送してから接続する。

```bash
gcloud compute scp --recurse k8s \
  "$(terraform output -raw bastion_name):~/k8s" \
  --zone="$(terraform output -raw zone)" \
  --project="$(terraform output -raw project_id)" --tunnel-through-iap

terraform output -raw get_credentials_example   # 控えておく
eval "$(terraform output -raw ssh_bastion_example)"
```

```bash
# 踏み台で。控えた get-credentials を実行してから
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

`logName`は`stdout`のまま。今回の`<format> @type json`では、Fluentdの`tag app.log`が出力に現れない。[既定のstdoutフォーマッタ](https://docs.fluentd.org/output/stdout)は時刻とtagも出す。

上の出力に`fluentd_tag=app.log`があるのは、`record_transformer`で`fluentd_tag ${tag}`と**明示的に入れたから**。入れなければtagは失われる。

### 6. この設定ではアプリのJSONが文字列になる

この設定次第で、アプリのJSON内の値を構造化フィールドとして検索できるかが決まる。

```json
{
  "env": "verification",
  "fluentd_tag": "app.log",
  "service": "order-api",
  "message": "{\"msg\":\"APP json line to file\",\"order_id\":2345}"
}
```

アプリが書いたJSONが、**文字列のまま`message`に入っている。** `jsonPayload.order_id=2345`という構造化フィールドの検索はできない。[文字列の部分一致](https://cloud.google.com/logging/docs/view/logging-query-language#comparison_operators)（`jsonPayload.message:"order_id"`）なら引ける。

原因は`fluent.conf`の`<parse> @type none`。Fluentdは行を解釈せず、生のテキストとして`message`に詰める。

```
<source>
  @type tail
  <parse>
    @type none      ← ここ
  </parse>
</source>
```

**原因はサイドカーではなく[パーサの指定](https://docs.fluentd.org/parser/none)。** `@type none`は行をそのまま単一フィールドに入れる。

ただし`@type json`に変えるだけでは足りない。このマニフェストは通常のテキスト行とJSON行を同じファイルに書いており、[`in_tail`の`emit_unmatched_lines`は既定でfalse](https://docs.fluentd.org/input/tail#emit_unmatched_lines)なので、**JSONでない行が転送されなくなる。** 入力を1行1JSONに揃えるか、不一致行を保持する設定が要る。

### 7. 複数行がどう入るかは確かめきれなかった

```console
$ gcloud logging read '... AND labels."k8s-pod/app"="multiline"' --format="value(textPayload)"
MULTILINE-END
MULTILINE-START java.lang.NullPointerException: order is null
	at com.example.OrderService.process(OrderService.java:42)
	at com.example.OrderController.post(OrderController.java:18)
MULTILINE-END
```

この出力からエントリの境界は読み取れない。`value(textPayload)`はエントリを改行で繋ぐだけなので、4行が1件でも4件でも同じ見た目になる。

表示順から推し量ることもできない。降順は`timestamp`に基づき、同一時刻のエントリは[`insertId`順](https://docs.cloud.google.com/logging/docs/reference/v2/rest/v2/entries/list)になるので、アプリの出力順との対応がそもそも取れない。

**確かめていない。** 環境を削除した後に気づいたため測り直せていない。次に立てたときは、対象Podと時間範囲を絞って`--format=json`で取得し、各オブジェクトの`timestamp`・`insertId`・`textPayload`を見て、`START`とスタックトレースが同じ`textPayload`に入るかを判定する。

1件にまとめたい場合は、アプリ側でスタックトレースを文字列フィールドに入れ、改行を`\n`にエスケープした1行JSONを標準出力へ出す。Fluentdで結合するなら、対象ログを共有ファイルに出して`in_tail`で読み、[`multiline`パーサ](https://docs.fluentd.org/parser/multiline)を設定する（今回のmultiline PodはFluentdを通っていないので、そのままでは適用できない）。

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

- **今回の入力では、素のテキストは`textPayload`、`msg`と`order_id`を含むJSONは`jsonPayload`に入った。** [ドキュメント](https://docs.cloud.google.com/logging/docs/structured-logging#special-payload-fields)は、特別扱いのフィールドを移したあと`message`だけが残り`detect_json`が無効なら`textPayload`になるとしている。`detect_json`はGKEのようなマネージド環境には適用されないので、GKEはこの条件に当たる。ただし今回の入力に`message`だけのJSONは無く、未検証
- **JSON内の`severity`はエントリに昇格し、`jsonPayload`からは消える**
- **標準出力に1行JSONを書くなら、構造化のためのFluentdサイドカーは要らない。** ファイル出力を今回と同じGKE標準エージェントの経路に載せるなら標準出力への転送が要る。ファイルを読んでCloud LoggingへAPIで直接送る構成も選べる
- Fluentdが`record_transformer`で足したキーは`jsonPayload`のキーになる。`severity`も昇格する
- **今回の`<format> @type json`ではtagが付かない。** `record_transformer`で`fluentd_tag ${tag}`を足して保持した。既定のstdoutフォーマッタなら時刻とtagも出る
- **原因はサイドカーではなく`@type none`。** 行がそのまま単一フィールドに入るので、アプリのJSONが文字列として`message`に入る。`@type json`に変えるだけでは足りず、通常テキスト行が混ざると`emit_unmatched_lines`の既定falseで落ちる
- **複数行の扱いは未確認。** `value(textPayload)`はエントリを改行で繋ぐだけで境界を示さない。降順表示で`START`の後に`at`が続くのはむしろ結合の示唆。`--format=json`の`insertId`で確かめること

## 参考資料

- [Google Cloud: About logging in GKE](https://cloud.google.com/kubernetes-engine/docs/concepts/about-logs)
- [Google Cloud: Configure logging for GKE](https://cloud.google.com/kubernetes-engine/docs/how-to/configure-logging)
- [Google Cloud: Structured logging](https://cloud.google.com/logging/docs/structured-logging)
- [Fluentd: record_transformer filter](https://docs.fluentd.org/filter/record_transformer)
- [Terraform Registry: google_container_cluster](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_cluster)
