#!/bin/bash
# Terraform hands over to Ansible here.
#
# Runs on FIRST BOOT ONLY. A reboot does not re-run it, so editing the
# playbook and restarting the VM changes nothing -- see the README.
set -euxo pipefail

LOG=/var/log/startup-ansible.log
exec > >(tee -a "$LOG") 2>&1
echo "startup-ansible: BEGIN $(date -Is)"

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq ansible

WORKDIR=/opt/ansible
mkdir -p "$WORKDIR"

# gcloud storage is present on the Debian image via the Google Cloud CLI.
gcloud storage rsync -r "gs://${bucket}/ansible" "$WORKDIR"

cd "$WORKDIR"
ansible-playbook -i inventory.ini "playbooks/${playbook}" -c local

echo "startup-ansible: END $(date -Is)"
