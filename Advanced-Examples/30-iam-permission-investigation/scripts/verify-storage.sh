#!/usr/bin/env bash
# tf-adv-iam-subject を借用し、同じオブジェクトを gcloud と REST API で読む。
# あわせて、Console が裏で行う「バケット一覧」「バケットの取得」も同じ Principal で試す。
# 使い方: bash scripts/verify-storage.sh <PROJECT_ID>
set -u

PROJECT_ID="${1:?PROJECT_ID を指定する}"
BUCKET="${PROJECT_ID}-tf-adv-iam"
SA="tf-adv-iam-subject@${PROJECT_ID}.iam.gserviceaccount.com"

run() {
  echo "\$ $*"
  "$@" 2>&1 | grep -v -E 'FutureWarning|warnings\.warn|service account impersonation'
  echo "exit=${PIPESTATUS[0]}"
  echo
}

http() {
  local label="$1" url="$2"
  echo "\$ curl ${label}"
  curl -s -w '\nhttp=%{http_code}\n' -H "Authorization: Bearer ${TOKEN}" "${url}"
  echo
}

echo "### $(date -u +%FT%TZ)"

# gcloud
run gcloud storage cat "gs://${BUCKET}/hello.txt" --impersonate-service-account="${SA}"
run gcloud storage ls "gs://${BUCKET}" --impersonate-service-account="${SA}"
run gcloud storage buckets describe "gs://${BUCKET}" --format='value(name)' --impersonate-service-account="${SA}"
run gcloud storage ls --project="${PROJECT_ID}" --impersonate-service-account="${SA}"

# REST API（JSON API）
TOKEN="$(gcloud auth print-access-token --impersonate-service-account="${SA}" 2>/dev/null)"
http "objects.get (alt=media)" "https://storage.googleapis.com/storage/v1/b/${BUCKET}/o/hello.txt?alt=media"
http "buckets.get" "https://storage.googleapis.com/storage/v1/b/${BUCKET}?fields=name"
http "buckets.list" "https://storage.googleapis.com/storage/v1/b?project=${PROJECT_ID}&fields=items/name"

# 呼び出し元が持つ Permission（testIamPermissions）は Recommender の利用実績に数えられるため、
# ここでは呼ばない。scripts/test-iam-permissions.sh で最後にまとめて実行する
