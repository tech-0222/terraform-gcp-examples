#!/bin/bash
set -euxo pipefail
mkdir -p /var/www
echo "backend-a" > /var/www/index.html
nohup python3 -m http.server 8080 --bind 0.0.0.0 --directory /var/www > /var/log/http.log 2>&1 &
sleep 1
