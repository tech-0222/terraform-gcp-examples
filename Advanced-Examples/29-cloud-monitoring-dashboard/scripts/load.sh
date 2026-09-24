#!/usr/bin/env bash
# Cloud Run に正常・5xx・遅延のリクエストを混ぜて送る。
# 使い方: bash scripts/load.sh <run_url> [分数]
set -euo pipefail

url="${1:?Cloud Run の URL を指定する}"
minutes="${2:-10}"
end=$(( $(date +%s) + minutes * 60 ))

while [ "$(date +%s)" -lt "$end" ]; do
  for _ in $(seq 1 20); do
    curl -s -o /dev/null "${url}/status/200" || true
  done
  curl -s -o /dev/null "${url}/delay/1" || true
  curl -s -o /dev/null "${url}/status/500" || true
  sleep 5
done
