#!/bin/bash
echo "=== C-VPS diagnose ==="
echo ""
echo "--- Porta 80 ---"
ss -tlnp | grep ':80 ' || netstat -tlnp 2>/dev/null | grep ':80 '
echo ""
echo "--- Containers com porta 80 ---"
docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Ports}}' | head -1
docker ps --format '{{.Names}}\t{{.Ports}}' | grep -E '(:80->|0\.0\.0\.0:80|:::80)' || echo "(nenhum)"
echo ""
echo "--- Todos os containers ---"
docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Ports}}'
echo ""
echo "--- Nginx no host ---"
command -v nginx && nginx -v 2>&1
systemctl is-active nginx 2>/dev/null || true
ls /etc/nginx/sites-enabled/ 2>/dev/null || true
echo ""
echo "--- Agente ---"
curl -s http://127.0.0.1:9876/health || echo "agente :9876 offline"
curl -s http://127.0.0.1/cvps/health | head -c 80 || true
echo ""
