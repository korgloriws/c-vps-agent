#!/bin/bash
# Finmas: finmas-app em 127.0.0.1:8080 (Docker)
# Porta 80: nginx no HOST — adiciona so /cvps/ -> agente :9876
set -e

MARKER="# C-VPS-AGENT-PROXY"

echo "=== C-VPS :: nginx no HOST (finmas intacto em /) ==="

if ! curl -sf http://127.0.0.1:9876/health >/dev/null; then
  echo "[ERRO] Agente offline. Rode: cd /opt/c-vps-agent && docker compose up -d"
  exit 1
fi

if ! command -v nginx >/dev/null; then
  echo "[ERRO] nginx nao instalado no host."
  exit 1
fi

CONF=""
for p in /etc/nginx/sites-enabled/* /etc/nginx/conf.d/*.conf; do
  [ -f "$p" ] || continue
  if grep -qE '8080|finmas|proxy_pass' "$p" 2>/dev/null; then
    CONF="$p"
    break
  fi
done
if [ -z "$CONF" ]; then
  for p in /etc/nginx/sites-enabled/default /etc/nginx/sites-enabled/finmas \
           /etc/nginx/conf.d/default.conf; do
    [ -f "$p" ] && CONF="$p" && break
  done
fi
if [ -z "$CONF" ]; then
  echo "[ERRO] Arquivo nginx nao encontrado."
  ls -la /etc/nginx/sites-enabled/ /etc/nginx/conf.d/ 2>/dev/null
  exit 1
fi

echo "Config: $CONF"
cp "$CONF" "${CONF}.bak.cvps-$(date +%Y%m%d)"

if grep -q "$MARKER" "$CONF"; then
  echo "[OK] /cvps/ ja configurado."
else
  python3 - "$CONF" "$MARKER" <<'PY'
import sys
path, marker = sys.argv[1], sys.argv[2]
text = open(path, encoding="utf-8").read()
block = f"""
    {marker}
    location /cvps/ {{
        proxy_pass http://127.0.0.1:9876/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_read_timeout 120s;
    }}
"""
for needle in ("location / {", "location /{", "location / "):
    if needle in text:
        text = text.replace(needle, block + "\n    " + needle, 1)
        open(path, "w", encoding="utf-8").write(text)
        print("Inserido antes de location /")
        sys.exit(0)
import re
m = re.search(r"server\s*\{", text)
if not m:
    sys.exit("Nao achei server { nem location /")
text = text[:m.end()] + block + text[m.end():]
open(path, "w", encoding="utf-8").write(text)
print("Inserido apos server {")
PY
fi

nginx -t
systemctl reload nginx

echo ""
echo "=== Testes ==="
echo -n "Finmas (/):       "
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1/
echo -n "Agente (/cvps/):  "
curl -s http://127.0.0.1/cvps/health
echo ""
echo "Painel: VPS_AGENT_URL = \"http://31.97.167.75/cvps\""
