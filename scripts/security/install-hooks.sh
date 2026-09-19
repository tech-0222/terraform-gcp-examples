#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "Git リポジトリではありません" >&2
  exit 2
}
cd "$ROOT"

if ! command -v pre-commit >/dev/null 2>&1; then
  echo "pre-commit がありません。https://pre-commit.com/#install を参照してください。" >&2
  exit 2
fi

pre-commit install --install-hooks --hook-type pre-commit --hook-type pre-push --hook-type commit-msg
echo "pre-commit / pre-push のGitleaks hookを設定しました。"
