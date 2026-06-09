#!/bin/bash
# Host nginx :80 -> finmas-app :8080
# Adiciona /cvps/ -> agente :9876 ANTES do location /
set -e

MARKER="# C-VPS-AGENT-PROXY"

echo "=== C-VPS :: nginx HOST ==="

if ! curl -sf http://127.0.0.1:9876/health >/dev/null; then
  echo "[ERRO] Agente offline: docker compose up -d em /opt/c-vps-agent"
  exit 1
fi

if ! command -v nginx >/dev/null; then
  echo "[ERRO] nginx nao encontrado no host."
  exit 1
fi

# Achar config que manda trafego pro finmas (8080)
CONF=""
for p in /etc/nginx/sites-enabled/* /etc/nginx/conf.d/*.conf; do
  [ -f "$p" ] || continue
  if grep -qE '8080|finmas' "$p" 2>/dev/null; then
    CONF="$p"
    break
  fi
done
if [ -z "$CONF" ]; then
  for p in /etc/nginx/sites-enabled/default /etc/nginx/sites-enabled/finmas; do
    [ -f "$p" ] && CONF="$p" && break
  done
fi
if [ -z "$CONF" ]; then
  echo "[ERRO] Config nginx nao encontrada."
  ls -la /etc/nginx/sites-enabled/ 2>/dev/null
  exit 1
fi

echo "Arquivo: $CONF"
cp "$CONF" "${CONF}.bak.cvps-$(date +%Y%m%d%H%M)"

if grep -q "$MARKER" "$CONF"; then
  echo "[OK] Bloco /cvps/ ja existe."
else
  python3 - "$CONF" "$MARKER" <<'PY'
import sys, re
path, marker = sys.argv[1], sys.argv[2]
text = open(path, encoding="utf-8").read()
block = f"""
    {marker}
    location ^~ /cvps/ {{
        proxy_pass http://127.0.0.1:9876/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_read_timeout 120s;
    }}
"""
# Inserir antes do primeiro location (finmas em /)
m = re.search(r"\n\s*location\s", text)
if m:
    pos = m.start()
    text = text[:pos] + "\n" + block + text[pos:]
else:
    m = re.search(r"server\s*\{", text)
    if not m:
        sys.exit("Nao achei server { nem location")
    text = text[:m.end()] + block + text[m.end():]
open(path, "w", encoding="utf-8").write(text)
print("Bloco /cvps/ inserido (prioridade ^~)")
PY
fi

echo "--- nginx -t ---"
nginx -t
systemctl reload nginx

echo ""
echo "=== Teste na VPS (obrigatorio antes do PC) ==="
echo -n "/cvps/health: "
R=$(curl -s http://127.0.0.1/cvps/health | head -c 60)
echo "$R"
if echo "$R" | grep -q '"ok"'; then
  echo "[OK] Proxy funcionando."
else
  echo "[ERRO] Ainda retorna HTML — envie: cat $CONF"
  exit 1
fi
echo -n "Finmas (/): "
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1/
echo ""
echo "PC: curl http://31.97.167.75/cvps/health"
