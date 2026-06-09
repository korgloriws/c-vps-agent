#!/bin/bash
# Adiciona location /cvps/ DENTRO do server do finmas.
# O Finmas em / nao e alterado — so encaminha /cvps/ para o agente.
set -e

AGENT_CTR="c-vps-agent"
AGENT_PORT="9876"
MARKER="# C-VPS-AGENT-PROXY"

echo "=== C-VPS :: proxy /cvps/ (finmas intacto em /) ==="

# 1) Agente rodando
if ! docker ps --format '{{.Names}}' | grep -qx "$AGENT_CTR"; then
  echo "[ERRO] Container $AGENT_CTR nao esta rodando."
  echo "       cd /opt/c-vps-agent && docker compose up -d"
  exit 1
fi

# 2) Achar nginx do finmas
NGINX_CTR="${NGINX_CTR:-}"
if [ -z "$NGINX_CTR" ]; then
  NGINX_CTR=$(docker ps --format '{{.Names}}' | grep -iE 'nginx|proxy' | grep -vi cvps | head -1)
fi
if [ -z "$NGINX_CTR" ]; then
  echo "[ERRO] Container nginx nao encontrado."
  echo "       docker ps"
  echo "       Depois: NGINX_CTR=nome_do_container bash $0"
  exit 1
fi
echo "Nginx: $NGINX_CTR"

# 3) Mesma rede Docker (nginx -> c-vps-agent)
NET=$(docker inspect "$NGINX_CTR" --format '{{range $k,$v := .NetworkSettings.Networks}}{{$k}}{{end}}' | head -1)
if [ -n "$NET" ]; then
  docker network connect "$NET" "$AGENT_CTR" 2>/dev/null || true
  echo "Rede: $NET"
fi

# 4) Achar arquivo de config
CONF_PATH=""
for p in \
  /etc/nginx/conf.d/default.conf \
  /etc/nginx/nginx.conf \
  /etc/nginx/conf.d/finmas.conf; do
  if docker exec "$NGINX_CTR" test -f "$p" 2>/dev/null; then
    CONF_PATH="$p"
    break
  fi
done
if [ -z "$CONF_PATH" ]; then
  CONF_PATH=$(docker exec "$NGINX_CTR" sh -c 'ls /etc/nginx/conf.d/*.conf 2>/dev/null | head -1')
fi
if [ -z "$CONF_PATH" ]; then
  echo "[ERRO] Arquivo nginx nao encontrado no container."
  docker exec "$NGINX_CTR" find /etc/nginx -name '*.conf' 2>/dev/null || true
  exit 1
fi
echo "Config: $CONF_PATH"

TMP=$(mktemp)
docker exec "$NGINX_CTR" cat "$CONF_PATH" > "$TMP"

if grep -q "$MARKER" "$TMP"; then
  echo "[OK] Proxy /cvps/ ja configurado."
else
  BLOCK="
    $MARKER
    location /cvps/ {
        proxy_pass http://${AGENT_CTR}:${AGENT_PORT}/;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_read_timeout 120s;
    }
"
  # Inserir ANTES do primeiro "location /" (SPA finmas)
  python3 - "$TMP" "$BLOCK" <<'PY'
import sys
path, block = sys.argv[1], sys.argv[2]
text = open(path, encoding="utf-8").read()
needle = "location /"
if needle not in text:
    print("location / nao encontrado — cole manualmente o bloco /cvps/", file=sys.stderr)
    sys.exit(1)
text = text.replace(needle, block + "\n    " + needle, 1)
open(path, "w", encoding="utf-8").write(text)
PY
  docker cp "$TMP" "${NGINX_CTR}:${CONF_PATH}"
  echo "Bloco /cvps/ inserido em $CONF_PATH"
fi
rm -f "$TMP"

docker exec "$NGINX_CTR" nginx -t
docker exec "$NGINX_CTR" nginx -s reload

echo ""
echo "=== Testes ==="
echo -n "Finmas (/):       "
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1/
echo -n "Agente (/cvps/):  "
curl -s http://127.0.0.1/cvps/health
echo ""
IP=$(hostname -I 2>/dev/null | awk '{print $1}')
echo ""
echo "Painel local: VPS_AGENT_URL = \"http://${IP:-31.97.167.75}/cvps\""
