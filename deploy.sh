#!/bin/bash
# Mesmo fluxo do finmas: git pull + docker compose
set -e
cd "$(dirname "$0")"

echo "=== C VPS Agent :: deploy ==="
git pull
docker compose build
docker compose down
docker compose up -d

echo ""
echo "Health:"
sleep 2
curl -s http://127.0.0.1:9876/health || echo "(aguarde alguns segundos e teste de novo)"
echo ""
echo "Pronto. Firewall hPanel: Accept TCP 9876"
