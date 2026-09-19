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
# **使ったツールを出す。** GitHub の runner には shellcheck が入っており、
# 手元の Docker と版が違う。版が違えば出る指摘も違い、実際に SC2317 が
# CI でだけ出た。どちらで動いたか分からないまま結果だけを見ない。
#
# **関数を名前で間接的に呼ばない。** shellcheck からは到達不能に見え、
# SC2317 と SC2329 が出る。抑制で黙らせるより、直接呼ぶほうが確か。
#
#   bash scripts/lint_sources.sh [shell|actions|all]
set -uo pipefail

readonly SHELLCHECK_IMAGE="koalaman/shellcheck:v0.11.0"
readonly ACTIONLINT_IMAGE="rhysd/actionlint:1.7.12"

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "Git リポジトリではありません" >&2
  exit 2
}
cd "$ROOT" || exit 2

# -x は source したファイルを追跡する。付けないと SC1091 が出る。
# -P SCRIPTDIR は、その source をスクリプト自身の位置から解決する。
lint_shell() {
  local files
  mapfile -t files < <(git ls-files '*.sh')
  if [ "${#files[@]}" -eq 0 ]; then
    echo "対象の .sh がありません"
    return 0
  fi

  if command -v shellcheck >/dev/null 2>&1; then
    echo "使用: $(shellcheck --version | awk '/^version:/ {print "shellcheck " $2}') (PATH)"
    shellcheck -x -P SCRIPTDIR -f gcc "${files[@]}"
  elif command -v docker >/dev/null 2>&1; then
    echo "使用: ${SHELLCHECK_IMAGE} (Docker)"
    docker run --rm -v "$ROOT":/mnt -w /mnt "$SHELLCHECK_IMAGE" \
      -x -P SCRIPTDIR -f gcc "${files[@]}"
  else
    echo "shellcheck も Docker もありません。検査を実行できません。" >&2
    return 2
  fi
}

lint_actions() {
  if [ ! -d .github/workflows ]; then
    echo ".github/workflows がありません"
    return 0
  fi

  if command -v actionlint >/dev/null 2>&1; then
    echo "使用: actionlint $(actionlint -version | head -1) (PATH)"
    actionlint -no-color
  elif command -v docker >/dev/null 2>&1; then
    echo "使用: ${ACTIONLINT_IMAGE} (Docker)"
    # actionlint は .git を見てリポジトリ根を決める。読み取り専用で渡すと
    # 「no project was found」で何も検査せずに 0 を返す。
    docker run --rm -v "$ROOT":/repo -w /repo "$ACTIONLINT_IMAGE" -no-color
  else
    echo "actionlint も Docker もありません。検査を実行できません。" >&2
    return 2
  fi
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
  [ -z "$out" ] || echo "$out"
  return 0
}

failed=0
broken=0

# `cond && a || b` は a が失敗したときも b に落ちる。分岐は if で書く。
note() {
  if [ "$1" -ge 2 ]; then
    broken=1
  elif [ "$1" -ne 0 ]; then
    failed=1
  fi
}

want="${1:-all}"
case "$want" in
  shell|actions|all) ;;
  *) echo "使い方: $0 shell|actions|all" >&2; exit 2 ;;
esac

if [ "$want" = "shell" ] || [ "$want" = "all" ]; then
  out="$(lint_shell 2>&1)"
  status=$?
  report shellcheck "$status" "$out"
  note $?
fi

if [ "$want" = "actions" ] || [ "$want" = "all" ]; then
  out="$(lint_actions 2>&1)"
  status=$?
  report actionlint "$status" "$out"
  note $?
fi

if [ "$broken" -eq 1 ]; then
  echo "検査を実行できませんでした。通ったことにはしません。"
  exit 2
fi
exit "$failed"
