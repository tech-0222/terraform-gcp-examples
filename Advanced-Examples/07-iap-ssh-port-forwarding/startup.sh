#!/usr/bin/env bash
set -euxo pipefail

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y nginx

cat >/var/www/html/index.html <<'HTML'
<!doctype html>
<html lang="ja">
<head>
  <meta charset="utf-8">
  <title>IAP SSH port forwarding test</title>
</head>
<body>
  <h1>IAP SSH port forwarding works</h1>
  <p>This HTTP endpoint is reachable without exposing port 80.</p>
</body>
</html>
HTML

systemctl enable --now nginx

# Ops Agent。GCE では入っているのが普通で、入れないと VM 内の記録が
# Cloud Logging に一切出ない。roles/logging.logWriter とセットで効く。
curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh
bash add-google-cloud-ops-agent-repo.sh --also-install

# 既定の収集対象は syslog で、Debian は auth,authpriv を syslog から外す。
# sshd と sudo の記録は auth.log にあるため、明示的に足す。
cat >/etc/google-cloud-ops-agent/config.yaml <<'YAML'
logging:
  receivers:
    auth:
      type: files
      include_paths: [/var/log/auth.log]
  service:
    pipelines:
      auth_pipeline:
        receivers: [auth]
YAML
systemctl restart google-cloud-ops-agent
