#!/bin/bash
# Aumenta proxy_read_timeout do /cvps/ para 5 min
set -e
FILE="/etc/nginx/sites-available/finmas"
[ -f "$FILE" ] || FILE=$(grep -rl "cvps" /etc/nginx/sites-enabled/ | head -1)
[ -f "$FILE" ] || { echo "Arquivo nginx nao encontrado"; exit 1; }
sed -i 's/proxy_read_timeout 120s/proxy_read_timeout 300s/g' "$FILE"
grep "proxy_read_timeout" "$FILE" || true
nginx -t && systemctl reload nginx
echo "[OK] nginx timeout 300s"
