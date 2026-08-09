# Basic-Examples

基本サンプル（単体・最小構成）を置く場所です。

各ディレクトリは Terraform の独立した Root Module です。

複数サービス連携などの応用コードは `../Advanced-Examples/` を参照してください。

## 進め方

1. 最初は `00-provider-check` を実行し、Terraformから対象の Google Cloud Project を参照できることを確認する
2. 続けて `01-project-service` で API 有効化を試す
3. 番号順に各リソースの最小サンプルを確認する

応用・複合の試験は `Advanced-Examples/` 側に追加していきます。

## 自動生成ドキュメント

各サンプルディレクトリには次が含まれます（手動編集しない）。

- `PARAMETER.md` … terraform-docs
- `DEPENDENCY-GRAPH.svg` … terraform graph

再生成:

```bash
./scripts/generate-terraform-docs.sh --all
./scripts/generate-terraform-graphs.sh --all
```
