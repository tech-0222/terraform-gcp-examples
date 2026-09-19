#!/usr/bin/env bash
# シェルスクリプトと GitHub Actions を静的検査する。
#
# どちらも「書いた本人には見えない事故」を拾う。今セッションだけで、
# 自分自身にマッチする pgrep で終わらないループを2回書き、終了条件を
# 取り違えた監視ループで誤った完了通知を出した。ワークフローのほうは、
# untrusted input をインラインスクリプトに直接入れる形を検出できる。
#
# **導入時点でどちらも0件だった（実測）。** だから落とす対象にできる。
# 既存を落とさず、これから書くものだけが落ちる。
#
# 検査できないときは0を返さない。バイナリが無ければ Docker を使い、
# どちらも無ければ終了コード2で止める。「何も無い」と「調べられなかった」
# を同じ値で返さないため。
#
#   bash scripts/lint_sources.sh [shell|actions|all]
#
# run() が関数を名前で呼ぶため、shellcheck からは直接の呼び出しが見えない。
# ファイル全体への指示は、最初のコマンドより前に置かないと効かない。
# shellcheck disable=SC2329
set -uo pipefail


readonly SHELLCHECK_IMAGE="koalaman/shellcheck:v0.11.0"
readonly ACTIONLINT_IMAGE="rhysd/actionlint:1.7.12"

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "Git リポジトリではありません" >&2
  exit 2
}
cd "$ROOT" || exit 2

missing() {
  echo "$1 も Docker もありません。検査を実行できないので、通ったことにはしません。" >&2
  exit 2
}

# -x は source したファイルを追跡する。付けないと SC1091 が出る。
# -P SCRIPTDIR は、その source をスクリプト自身の位置から解決する。
lint_shell() {
  local files
  mapfile -t files < <(git ls-files '*.sh')
  if [ "${#files[@]}" -eq 0 ]; then
    echo "  対象の .sh がありません"
    return 0
  fi

  if command -v shellcheck >/dev/null 2>&1; then
    shellcheck -x -P SCRIPTDIR -f gcc "${files[@]}"
  elif command -v docker >/dev/null 2>&1; then
    docker run --rm -v "$ROOT":/mnt -w /mnt "$SHELLCHECK_IMAGE" \
      -x -P SCRIPTDIR -f gcc "${files[@]}"
  else
    missing shellcheck
  fi
}

lint_actions() {
  if [ ! -d .github/workflows ]; then
    echo "  .github/workflows がありません"
    return 0
  fi

  if command -v actionlint >/dev/null 2>&1; then
    actionlint -no-color
  elif command -v docker >/dev/null 2>&1; then
    # actionlint は .git を見てリポジトリ根を決める。読み取り専用で渡すと
    # 「no project was found」で何も検査せずに 0 を返す。
    docker run --rm -v "$ROOT":/repo -w /repo "$ACTIONLINT_IMAGE" -no-color
  else
    missing actionlint
  fi
}

run() {
  local name="$1" fn="$2" out status
  out="$("$fn" 2>&1)"
  status=$?
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
  [ -z "$out" ] || echo "$out"
  return 0
}

failed=0
broken=0

# `cond && a || b` は a が失敗したときも b に落ちる。分岐は if で書く。
record() {
  if [ "$1" -ge 2 ]; then
    broken=1
  elif [ "$1" -ne 0 ]; then
    failed=1
  fi
}

case "${1:-all}" in
  shell)
    run shellcheck lint_shell
    record $?
    ;;
  actions)
    run actionlint lint_actions
    record $?
    ;;
  all)
    run shellcheck lint_shell
    record $?
    run actionlint lint_actions
    record $?
    ;;
  *)
    echo "使い方: $0 shell|actions|all" >&2
    exit 2
    ;;
esac

if [ "$broken" -eq 1 ]; then
  echo "検査を実行できませんでした。通ったことにはしません。"
  exit 2
fi
exit "$failed"
