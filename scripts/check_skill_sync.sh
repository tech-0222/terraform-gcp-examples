#!/usr/bin/env bash
# `.agents/` と `.claude/` に同じ内容を二重に置いているので、ズレを検出する。
#
# 同じ skill を2箇所に置いているのは、読む側が違うため。差分は front matter
# の `allowed-tools:` 1行だけで、本文は同一であることを前提にしている。
# **その前提は、片方だけ直したときに黙って崩れる。** どちらが正しいのかは
# あとから見分けられない。
#
# 比較するのは `.agents/` にあるものだけ。`.claude/` にしか無い skill は
# 対象外で、ズレではない（hugo-blog は6つのうち1つだけを `.agents` に
# 置いている）。**片側だけに在ることと、両方に在って食い違うことは別。**
#
# 許す差分は `allowed-tools:` 行の削除だけ。本文が1文字でも違えば落とす。
#
# 検査できないときは0を返さない。
#
#   bash scripts/check_skill_sync.sh
set -uo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "Git リポジトリではありません" >&2
  exit 2
}
cd "$ROOT" || exit 2

if [ ! -d .agents ]; then
  echo "  OK  skill の同期（.agents がありません）"
  exit 0
fi

mapfile -t mirrored < <(cd .agents && find . -name '*.md' | sed 's|^\./||' | sort)
if [ "${#mirrored[@]}" -eq 0 ]; then
  echo "  OK  skill の同期（.agents に .md がありません）"
  exit 0
fi

failed=0
checked=0

for rel in "${mirrored[@]}"; do
  agents=".agents/${rel}"
  claude=".claude/${rel}"

  if [ ! -f "$claude" ]; then
    echo "::error::${claude} がありません（${agents} と対になる相手）"
    failed=1
    continue
  fi

  # 許すのは allowed-tools 行の削除だけ。それ以外の差分が残れば落とす。
  drift="$(diff <(grep -v '^allowed-tools:' "$claude") "$agents")"
  if [ -n "$drift" ]; then
    echo "::error::${claude} と ${agents} の本文が食い違っています"
    printf '%s\n' "$drift" | sed 's/^/    /'
    failed=1
    continue
  fi

  # .agents 側に allowed-tools が残っていたら、削り忘れではなく別物になる。
  if grep -q '^allowed-tools:' "$agents"; then
    echo "::error::${agents} に allowed-tools があります（.agents 側では持たない）"
    failed=1
    continue
  fi

  checked=$((checked + 1))
done

if [ "$failed" -ne 0 ]; then
  echo "  .agents 側は .claude 側から allowed-tools 行を除いたものにします。"
  exit 1
fi

echo "  OK  skill の同期（${checked} 組。差分は allowed-tools 行のみ）"
exit 0
