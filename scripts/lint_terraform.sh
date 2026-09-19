#!/usr/bin/env bash
# Terraform の書式を検査する。
#
# **Git 管理下のファイルだけを見る。** `terraform fmt -recursive` は作業
# ツリー全体を走るので、gitignore した `terraform.tfvars` まで対象に入る。
# あれは各自の手元の値で、整列の仕方は人によって違う。落とす理由が無い。
#
# 実際、導入前に測ったときは4件出たが、4件とも未追跡の `terraform.tfvars`
# だった。追跡下の `.tf` は292ファイルすべて整形済みで0件。だから落とす
# 対象にできる。
#
# `terraform fmt` は `-check` を付けないとファイルを書き換える。`-diff`
# だけでは確認にならない（実際にローカルの tfvars を書き換えてしまった）。
# ここでは必ず `-check` を付ける。
#
# 検査できないときは0を返さない。terraform が無ければ終了コード2で止める。
#
#   bash scripts/lint_terraform.sh
set -uo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "Git リポジトリではありません" >&2
  exit 2
}
cd "$ROOT" || exit 2

if ! command -v terraform >/dev/null 2>&1; then
  echo "terraform がありません。検査を実行できないので、通ったことにはしません。" >&2
  exit 2
fi

echo "使用: $(terraform version | head -1)"

# -check は書き換えず、整形が要るファイルの一覧だけを出す。
unformatted="$(terraform fmt -check -recursive 2>/dev/null)"

tracked=""
while IFS= read -r file; do
  [ -n "$file" ] || continue
  if git ls-files --error-unmatch "$file" >/dev/null 2>&1; then
    tracked+="  ${file}"$'\n'
  fi
done <<< "$unformatted"

if [ -n "$tracked" ]; then
  echo "::error::terraform fmt"
  echo "整形されていない追跡ファイルがあります。"
  printf '%s' "$tracked"
  echo "  terraform fmt -recursive で直せます。"
  exit 1
fi

ignored="$(printf '%s' "$unformatted" | grep -c .)"
echo "  OK  terraform fmt（追跡下の .tf: $(git ls-files '*.tf' | wc -l) ファイル）"
if [ "$ignored" -gt 0 ]; then
  echo "  未追跡のファイル ${ignored} 件は対象外（各自の terraform.tfvars など）"
fi
exit 0
