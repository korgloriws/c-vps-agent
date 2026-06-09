#!/bin/bash
# Adiciona location /cvps/ — Finmas em / nao e alterado.
set -e

AGENT_CTR="c-vps-agent"
AGENT_PORT="9876"
MARKER="# C-VPS-AGENT-PROXY"

insert_cvps_block() {
  local file="$1"
  if grep -q "$MARKER" "$file"; then
    echo "[OK] Proxy ja existe em $file"
    return 0
  fi
  python3 - "$file" "$MARKER" "$AGENT_CTR" "$AGENT_PORT" <<'PY'
import sys
path, marker, agent, port = sys.argv[1:5]
text = open(path, encoding="utf-8").read()
block = f"""
    {marker}
    location /cvps/ {{
        proxy_pass http://{agent}:{port}/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_read_timeout 120s;
    }}
"""
for needle in ("location / {", "location /{"):
    if needle in text:
        text = text.replace(needle, block + "\n    " + needle, 1)
        open(path, "w", encoding="utf-8").write(text)
        print(f"Inserido em {path} antes de location /")
        sys.exit(0)
# fallback: dentro do primeiro server {
import re
m = re.search(r"server\s*\{", text)
if not m:
    print("Nao achei server { nem location /", file=sys.stderr)
    sys.exit(1)
pos = m.end()
text = text[:pos] + block + text[pos:]
open(path, "w", encoding="utf-8").write(text)
print(f"Inserido em {path} apos server {{")
PY
}

connect_agent_network() {
  local nginx_ctr="$1"
  local net
  net=$(docker inspect "$nginx_ctr" --format '{{range $k,$v := .NetworkSettings.Networks}}{{$k}}{{end}}' | head -1)
  if [ -n "$net" ]; then
    docker network connect "$net" "$AGENT_CTR" 2>/dev/null || true
    echo "Rede Docker: $net"
  fi
}

install_docker_nginx() {
  local nginx_ctr="$1"
  echo "Modo: nginx no container $nginx_ctr"
  connect_agent_network "$nginx_ctr"

  local conf=""
  for p in /etc/nginx/conf.d/default.conf /etc/nginx/nginx.conf; do
    docker exec "$nginx_ctr" test -f "$p" 2>/dev/null && conf="$p" && break
  done
  if [ -z "$conf" ]; then
    conf=$(docker exec "$nginx_ctr" sh -c 'ls /etc/nginx/conf.d/*.conf 2>/dev/null | head -1')
  fi
  [ -n "$conf" ] || { echo "[ERRO] conf nginx nao encontrada no container"; exit 1; }

  local tmp
  tmp=$(mktemp)
  docker exec "$nginx_ctr" cat "$conf" > "$tmp"
  insert_cvps_block "$tmp"
  docker cp "$tmp" "${nginx_ctr}:${conf}"
  rm -f "$tmp"

  docker exec "$nginx_ctr" nginx -t
  docker exec "$nginx_ctr" nginx -s reload
}

install_host_nginx() {
  echo "Modo: nginx no host (Linux)"
  local conf=""
  for p in /etc/nginx/sites-enabled/default /etc/nginx/conf.d/default.conf; do
    [ -f "$p" ] && conf="$p" && break
  done
  [ -n "$conf" ] || { echo "[ERRO] nginx host sem default.conf"; ls /etc/nginx/sites-enabled/; exit 1; }

  cp "$conf" "${conf}.bak.cvps"
  # Host nginx alcanca agente em 127.0.0.1:9876
  AGENT_CTR="127.0.0.1"
  insert_cvps_block "$conf"
  AGENT_CTR="c-vps-agent"
  nginx -t
  systemctl reload nginx
}

find_port80_container() {
  docker ps --format '{{.Names}}' | while read -r name; do
    docker port "$name" 2>/dev/null | grep -qE '80/tcp' && echo "$name" && return
  done
}

echo "=== C-VPS :: proxy /cvps/ (finmas intacto em /) ==="

if ! docker ps --format '{{.Names}}' | grep -qx "$AGENT_CTR"; then
  echo "[ERRO] Rode: cd /opt/c-vps-agent && docker compose up -d"
  exit 1
fi

NGINX_CTR="${NGINX_CTR:-}"

if [ -z "$NGINX_CTR" ]; then
  NGINX_CTR=$(docker ps --format '{{.Names}}\t{{.Ports}}' | grep -E '0\.0\.0\.0:80->|:::80->|\*:80->' | cut -f1 | head -1)
fi
if [ -z "$NGINX_CTR" ]; then
  NGINX_CTR=$(find_port80_container | head -1)
fi
if [ -z "$NGINX_CTR" ]; then
  NGINX_CTR=$(docker ps --format '{{.Names}}' | grep -iE 'nginx|proxy|caddy|traefik|web' | grep -vi cvps | head -1)
fi

if [ -n "$NGINX_CTR" ]; then
  install_docker_nginx "$NGINX_CTR"
elif command -v nginx >/dev/null && systemctl is-active --quiet nginx 2>/dev/null; then
  install_host_nginx
else
  echo "[ERRO] Nao achei quem serve a porta 80."
  echo ""
  echo "Rode e me envie a saida:"
  echo "  bash diagnose.sh"
  echo ""
  echo "Ou informe o container manualmente:"
  echo "  docker ps"
  echo "  NGINX_CTR=nome_do_container bash safe-nginx-install.sh"
  exit 1
fi

echo ""
echo "=== Testes ==="
echo -n "Finmas (/):       "
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1/
echo -n "Agente (/cvps/):  "
curl -s http://127.0.0.1/cvps/health
echo ""
IP=$(hostname -I 2>/dev/null | awk '{print $1}')
echo "Painel: VPS_AGENT_URL = \"http://${IP:-31.97.167.75}/cvps\""
