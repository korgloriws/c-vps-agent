#!/bin/bash
echo "=== sites-enabled ==="
ls -la /etc/nginx/sites-enabled/
echo ""
echo "=== default_server ==="
grep -rn "default_server" /etc/nginx/ 2>/dev/null | head -20
echo ""
echo "=== arquivos completos ==="
for f in /etc/nginx/sites-enabled/*; do
  [ -f "$f" ] || continue
  echo "######## $f ########"
  cat "$f"
  echo ""
done
echo "=== teste ==="
curl -s http://127.0.0.1/cvps/health | head -c 100
echo ""
