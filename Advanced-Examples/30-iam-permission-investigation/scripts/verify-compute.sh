#!/usr/bin/env bash
# tf-adv-iam-subject を借用し、Runtime SA を付けた VM を gcloud で作る。
# 成功したら同じ Principal で削除する（残すと次の段階の作成が名前の重複で失敗するため）。
# 使い方: bash scripts/verify-compute.sh <PROJECT_ID>
set -u

PROJECT_ID="${1:?PROJECT_ID を指定する}"
ZONE="asia-northeast1-a"
SA="tf-adv-iam-subject@${PROJECT_ID}.iam.gserviceaccount.com"
RUNTIME_SA="tf-adv-iam-vm-runtime@${PROJECT_ID}.iam.gserviceaccount.com"
VM="tf-adv-iam-vm-gcloud"

echo "### $(date -u +%FT%TZ)"
echo "\$ gcloud compute instances create ${VM} ..."
gcloud compute instances create "${VM}" \
  --project="${PROJECT_ID}" \
  --zone="${ZONE}" \
  --machine-type=e2-micro \
  --image-family=debian-12 --image-project=debian-cloud \
  --subnet=tf-adv-iam-vpc-subnet \
  --no-address \
  --shielded-secure-boot \
  --service-account="${RUNTIME_SA}" \
  --scopes=cloud-platform \
  --impersonate-service-account="${SA}" 2>&1 | grep -v -E 'FutureWarning|warnings\.warn|service account impersonation'
rc=${PIPESTATUS[0]}
echo "exit=${rc}"
echo

if [ "${rc}" -eq 0 ]; then
  echo "\$ gcloud compute instances delete ${VM} ..."
  gcloud compute instances delete "${VM}" --project="${PROJECT_ID}" --zone="${ZONE}" --quiet \
    --impersonate-service-account="${SA}" 2>&1 | grep -v -E 'FutureWarning|warnings\.warn|service account impersonation'
  echo "exit=${PIPESTATUS[0]}"
fi
