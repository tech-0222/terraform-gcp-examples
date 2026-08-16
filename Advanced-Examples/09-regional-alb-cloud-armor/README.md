# 09 - Regional External ALB + Cloud Armor

`08-regional-external-alb-neg` と同型の Regional External ALB に、**リージョナル Cloud Armor** を付けます。許可した送信元 IP だけ 200、それ以外は **403** です。

ネットワーク項目の正本は 08 の `docs/RESOURCE-PARAMETERS.md` です。ここでは Armor の差分だけ書きます。

## 確認すること

- 許可リストの IP から `http://VIP/` が 200 / `backend-a`
- 許可リスト外から 403（バックエンドへ到達しない）
- 同一 VPC から `:8080` 直叩きは Armor の対象外

## 設定方法

```bash
cd Advanced-Examples/09-regional-alb-cloud-armor
cp terraform.tfvars.example terraform.tfvars
```

`allowed_src_ips` に自分のグローバル IPv4 を `/32` で入れます。空のまま apply しないでください。

```bash
terraform init
terraform apply
curl -si "http://$(terraform output -raw vip)/"
```

任意で `create_deny_client = true` にすると、エフェメラル外部 IP の VM から VIP を叩いて 403 を確認できます。

## 削除方法

```bash
terraform destroy
```

Backend Service がポリシーを参照したままだとポリシー削除に失敗することがあります。その場合は BS から security policy を外してから destroy するか、もう一度 apply / destroy します。コード側は `lifecycle { create_before_destroy = true }` をポリシーに付けています。

**必ず destroy してください。**
