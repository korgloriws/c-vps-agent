#!/bin/bash
# Expoe o agente em http://SEU_IP/cvps/ (porta 80 — passa na rede corporativa)
set -e
cd "$(dirname "$0")"

SNIPPET="/etc/nginx/snippets/c-vps-agent.conf"
cp nginx-cvps.conf "$SNIPPET"

echo "Snippet instalado em $SNIPPET"
echo ""
echo "Adicione esta linha DENTRO do bloco server { } do seu site (ex. finmas):"
echo '    include snippets/c-vps-agent.conf;'
echo ""

# Tenta achar config nginx no host
SITE=""
for f in /etc/nginx/sites-enabled/* /etc/nginx/conf.d/*.conf; do
  [ -f "$f" ] || continue
  if grep -q "listen.*80" "$f" 2>/dev/null; then
    SITE="$f"
    break
  fi
done

if [ -n "$SITE" ] && ! grep -q "c-vps-agent" "$SITE" 2>/dev/null; then
  echo "Config encontrada: $SITE"
  read -r -p "Incluir snippet automaticamente? [s/N] " ans
  if [ "$ans" = "s" ] || [ "$ans" = "S" ]; then
    sed -i '/server {/a \    include snippets/c-vps-agent.conf;' "$SITE"
    nginx -t
    systemctl reload nginx
    echo "[OK] Nginx recarregado."
  fi
else
  echo "Se nginx roda no Docker (finmas), monte o snippet no container e recarregue."
fi

IP=$(hostname -I 2>/dev/null | awk '{print $1}')
echo ""
echo "Teste na VPS:"
echo "  curl http://127.0.0.1/cvps/health"
echo ""
echo "No painel local (backend/config.py):"
echo "  VPS_AGENT_URL = \"http://${IP:-31.97.167.75}/cvps\""
