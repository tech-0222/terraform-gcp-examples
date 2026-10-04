#!/usr/bin/env bash
# tf-adv-iam-subject を借用し、呼び出し元（= subject 自身）が持つ Permission を testIamPermissions で確かめる。
# 注意: testIamPermissions でテストした Permission は、IAM Recommender では「使用した」と数えられる。
# Recommender で過剰な権限を見たい Principal には、実操作と原因調査を終えてから最後に実行する。
# 使い方: bash scripts/test-iam-permissions.sh <PROJECT_ID>
set -u

PROJECT_ID="${1:?PROJECT_ID を指定する}"
BUCKET="${PROJECT_ID}-tf-adv-iam"
SA="tf-adv-iam-subject@${PROJECT_ID}.iam.gserviceaccount.com"
RUNTIME_SA="tf-adv-iam-vm-runtime@${PROJECT_ID}.iam.gserviceaccount.com"
TOKEN="$(gcloud auth print-access-token --impersonate-service-account="${SA}" 2>/dev/null)"

post() {
  local label="$1" url="$2" body="$3"
  echo "\$ curl -X POST ${label}"
  echo "  ${body}"
  curl -s -w '\nhttp=%{http_code}\n' -X POST -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" -d "${body}" "${url}"
  echo
}

echo "### $(date -u +%FT%TZ)"

# Cloud Storage: バケットに対する Permission（JSON API は GET）。
# storage.buckets.list はプロジェクトに対する Permission なので、ここに含めるとリクエスト全体が 400 になる
echo "\$ curl GET b/${BUCKET}/iam/testPermissions"
curl -s -w '\nhttp=%{http_code}\n' -G -H "Authorization: Bearer ${TOKEN}" \
  "https://storage.googleapis.com/storage/v1/b/${BUCKET}/iam/testPermissions" \
  --data-urlencode "permissions=storage.objects.get" \
  --data-urlencode "permissions=storage.objects.list" \
  --data-urlencode "permissions=storage.buckets.get"
echo

# プロジェクトに対する Permission（Compute の VM 作成に関わるものと、バケット一覧）
post "projects/${PROJECT_ID}:testIamPermissions" \
  "https://cloudresourcemanager.googleapis.com/v1/projects/${PROJECT_ID}:testIamPermissions" \
  '{"permissions":["compute.instances.create","compute.disks.create","compute.subnetworks.use","compute.instances.setServiceAccount","compute.instances.get","compute.instances.setLabels","compute.instances.delete","compute.zones.get","compute.disks.get","compute.instances.list","storage.buckets.list"]}'

# Runtime SA に対する actAs
post "serviceAccounts/${RUNTIME_SA}:testIamPermissions" \
  "https://iam.googleapis.com/v1/projects/${PROJECT_ID}/serviceAccounts/${RUNTIME_SA}:testIamPermissions" \
  '{"permissions":["iam.serviceAccounts.actAs","iam.serviceAccounts.getAccessToken"]}'
