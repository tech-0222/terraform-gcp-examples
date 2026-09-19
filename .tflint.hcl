# TFLint の設定。
#
# terraform ruleset は同梱で、未使用の宣言や非推奨の補間記法を見る。
# google ruleset は GCP 固有のルール用に入れているが、**導入時点では
# 0件だった**。値の妥当性検査は近年プロバイダ側に寄っており、このリポ
# ジトリの既存コードでは出るものが無かった。今後の新規コードのために
# 残している。
#
# プラグインは `tflint --init` で取得する。入っていないと、ルールが
# 少ないまま静かに 0 件で通るので、スクリプト側で存在を確認している。
plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

plugin "google" {
  enabled = true
  version = "0.34.0"
  source  = "github.com/terraform-linters/tflint-ruleset-google"
}
