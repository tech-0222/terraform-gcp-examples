#!/usr/bin/env bash
# Terraform の書式と、言語・プロバイダのルールを検査する。
#
#   fmt     terraform fmt -check（書式）
#   tflint  TFLint（未使用の宣言、非推奨の書き方、google のルール）
#
# **fmt は Git 管理下のファイルだけを見る。** `terraform fmt -recursive` は
# 作業ツリー全体を走るので、gitignore した `terraform.tfvars` まで対象に
# 入る。あれは各自の手元の値で、整列の仕方は人によって違う。実際、導入前
# に測ったときの4件は全部それだった。追跡下の `.tf` 292ファイルはすべて
# 整形済みで0件。
#
# **`terraform fmt` は `-check` を付けないとファイルを書き換える。**
# 確認のつもりで `-diff` だけを付けて実行し、ローカルの tfvars を書き換えて
# しまった。ここでは必ず `-check` を付ける。
#
# TFLint も導入時点で0件だった。0件が「検査していない」ではないことは、
# わざと違反を置いて確認してある（`terraform_unused_declarations` と
# `terraform_deprecated_interpolation` が出ることを確認）。
#
# 検査できないときは0を返さない。ツールが無ければ終了コード2で止める。
#
#   bash scripts/lint_terraform.sh [fmt|tflint|all]
set -uo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "Git リポジトリではありません" >&2
  exit 2
}
cd "$ROOT" || exit 2

check_fmt() {
  if ! command -v terraform >/dev/null 2>&1; then
    echo "terraform がありません。検査を実行できません。" >&2
    return 2
  fi
  echo "使用: $(terraform version | head -1)"

  local unformatted tracked="" file
  unformatted="$(terraform fmt -check -recursive 2>/dev/null)"
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    if git ls-files --error-unmatch "$file" >/dev/null 2>&1; then
      tracked+="  ${file}"$'\n'
    fi
  done <<< "$unformatted"

  if [ -n "$tracked" ]; then
    echo "整形されていない追跡ファイルがあります。"
    printf '%s' "$tracked"
    echo "  terraform fmt -recursive で直せます。"
    return 1
  fi

  local ignored
  ignored="$(printf '%s' "$unformatted" | grep -c .)"
  echo "追跡下の .tf: $(git ls-files '*.tf' | wc -l) ファイル"
  if [ "$ignored" -gt 0 ]; then
    echo "未追跡のファイル ${ignored} 件は対象外（各自の terraform.tfvars など）"
  fi
  return 0
}

check_tflint() {
  if ! command -v tflint >/dev/null 2>&1; then
    echo "tflint がありません。検査を実行できません。" >&2
    return 2
  fi
  echo "使用: $(tflint --version | head -1)"

  # プラグインが入っていないと、ルールが少ないまま静かに 0 件で通る。
  if [ ! -d "${HOME}/.tflint.d/plugins" ] && [ ! -d .tflint.d/plugins ]; then
    echo "プラグインが入っていません。tflint --init を実行してください。" >&2
    return 2
  fi

  # tflint の終了コードは 0=指摘なし / 2=指摘あり / 1=エラー。
  # そのまま返すと「指摘あり」が「実行できない」に化ける。
  local out status
  out="$(tflint --recursive --format=compact 2>&1)"
  status=$?
  [ -z "$out" ] || echo "$out"
  case "$status" in
    0) return 0 ;;
    2) return 1 ;;
    *) return 2 ;;
  esac
}

report() {
  local name="$1" status="$2" out="$3"
  if [ "$status" -ge 2 ]; then
    echo "::error::${name} を実行できません（終了コード ${status}）"
    [ -z "$out" ] || echo "$out"
    return 2
  fi
  if [ "$status" -ne 0 ]; then
    echo "::error::${name}"
    echo "$out"
    return 1
  fi
  echo "  OK  ${name}"
  if [ -n "$out" ]; then
    while IFS= read -r line; do printf '      %s\n' "$line"; done <<< "$out"
  fi
  return 0
}

failed=0
broken=0

note() {
  if [ "$1" -ge 2 ]; then
    broken=1
  elif [ "$1" -ne 0 ]; then
    failed=1
  fi
}

want="${1:-all}"
case "$want" in
  fmt|tflint|all) ;;
  *) echo "使い方: $0 fmt|tflint|all" >&2; exit 2 ;;
esac

if [ "$want" = "fmt" ] || [ "$want" = "all" ]; then
  out="$(check_fmt 2>&1)"
  status=$?
  report "terraform fmt" "$status" "$out"
  note $?
fi

if [ "$want" = "tflint" ] || [ "$want" = "all" ]; then
  out="$(check_tflint 2>&1)"
  status=$?
  report tflint "$status" "$out"
  note $?
fi

if [ "$broken" -eq 1 ]; then
  echo "検査を実行できませんでした。通ったことにはしません。"
  exit 2
fi
exit "$failed"
