#!/bin/bash
# Remove backups de sites-enabled que causam "duplicate upstream"
set -e
echo "Removendo .bak de sites-enabled..."
ls -la /etc/nginx/sites-enabled/*.bak* 2>/dev/null || echo "(nenhum)"
mkdir -p /etc/nginx/backups-cvps
for f in /etc/nginx/sites-enabled/*.bak*; do
  [ -f "$f" ] || continue
  mv "$f" /etc/nginx/backups-cvps/
  echo "Movido: $f"
done
echo "--- nginx -t ---"
nginx -t
systemctl reload nginx
echo ""
curl -s http://127.0.0.1/cvps/health
echo ""
