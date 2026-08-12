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
