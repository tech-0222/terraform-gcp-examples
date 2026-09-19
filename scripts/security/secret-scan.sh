#!/usr/bin/env bash
# Gitleaks のローカル実行入口。検出値は必ず redact する。
set -euo pipefail

readonly GITLEAKS_VERSION="8.30.1"
readonly IMAGE="ghcr.io/gitleaks/gitleaks:v${GITLEAKS_VERSION}"

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "Gitleaks: Git リポジトリではありません" >&2
  exit 2
}
cd "$ROOT"

run_gitleaks() {
  local output status
  set +e
  if command -v gitleaks >/dev/null 2>&1; then
    output="$(gitleaks "$@" 2>&1)"
    status=$?
  elif command -v docker >/dev/null 2>&1 && [ -d "$ROOT/.git" ]; then
    output="$(docker run --rm --user "$(id -u):$(id -g)" \
      -v "$ROOT:/repo:ro" -w /repo "$IMAGE" "$@" 2>&1)"
    status=$?
  else
    set -e
    echo "Gitleaks ${GITLEAKS_VERSION} をインストールするか、Dockerを起動してください。" >&2
    echo "検査を実行できないため、commit/pushを続けません。" >&2
    exit 2
  fi
  set -e

  if [ "$status" -eq 1 ]; then
    echo "Gitleaks: Secret候補を検出しました。値は表示しません。" >&2
    printf '%s\n' "$output" \
      | sed -E $'s/\033\[[0-9;]*[mK]//g' \
      | awk '/^(RuleID|File|Line|Commit):/ { print "  " $0 }' >&2
    return 1
  fi
  printf '%s\n' "$output"
  return "$status"
}

mode="${1:-}"
case "$mode" in
  staged)
    if git diff --cached --quiet --exit-code; then
      echo "Gitleaks: staged 変更がないため検査対象はありません。"
      exit 0
    fi
    run_gitleaks git --pre-commit --redact --staged --verbose
    ;;
  push)
    base="${GITLEAKS_BASE_REF:-origin/main}"
    if ! git rev-parse --verify -q "${base}^{commit}" >/dev/null; then
      echo "Gitleaks: 比較先 ${base} を読めません。git fetchして再実行してください。" >&2
      exit 2
    fi
    if [ "$(git rev-list --count "${base}..HEAD")" -eq 0 ]; then
      echo "Gitleaks: ${base} からpushするcommitはありません。"
      exit 0
    fi
    run_gitleaks git --redact --verbose --log-opts="${base}..HEAD"
    ;;
  all)
    run_gitleaks git --redact --verbose
    ;;
  *)
    echo "使い方: $0 staged|push|all" >&2
    exit 2
    ;;
esac
