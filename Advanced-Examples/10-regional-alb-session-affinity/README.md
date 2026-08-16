# 10 - Regional External ALB session affinity

同一 NEG 上の 2 VM（backend-a / backend-a2）に対し、Cookie でセッションを固定します。`:82`（1 台）は検証にならないため入れていません。

| ポート | session_affinity | Cookie |
|---|---|---|
| :81 | `GENERATED_COOKIE` | LB が `GCLB=` を発行 |
| :83 | `HTTP_COOKIE` + RING_HASH | アプリが `ROUTE=backend-a` または `backend-a2`（Path=/） |

ネットワークの正本は 08 の `docs/RESOURCE-PARAMETERS.md` です。

## 確認すること

- `:81` 初回に `Set-Cookie` があり、Cookie 付き 5 回が同じ identity
- `:83` 初回に `ROUTE=` があり、Cookie 付き 5 回が同じ identity
- Cookie なしでは a / a2 が混ざることがある（参考）

複数のフロントエンドが関与すると「常に同一」は保証されないことがあります。

## 使用方法

```bash
cd Advanced-Examples/10-regional-alb-session-affinity
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform apply
terraform output -raw curl_generated_cookie
terraform output -raw curl_http_cookie
```

## 削除方法

```bash
terraform destroy
```

**必ず destroy してください。**
