#!/bin/bash
# Instala o agente na VPS (rode no terminal do navegador do hPanel).
set -e

INSTALL_DIR="/opt/c-vps-agent"
SERVICE_NAME="c-vps-agent"
PORT=9876

echo "=== C VPS Agent :: instalacao ==="

if [ "$EUID" -ne 0 ]; then
  echo "Execute como root: sudo bash install.sh"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "[1/6] Copiando arquivos para ${INSTALL_DIR}..."
mkdir -p "$INSTALL_DIR"
cp "$SCRIPT_DIR/main.py" "$SCRIPT_DIR/config.py" "$SCRIPT_DIR/scanner.py" \
   "$SCRIPT_DIR/disk_parser.py" "$SCRIPT_DIR/scan.sh" \
   "$SCRIPT_DIR/requirements.txt" "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/scan.sh"

echo "[2/6] Instalando dependencias Python..."
python3 -m pip install -r "$INSTALL_DIR/requirements.txt" -q

echo "[3/6] Criando servico systemd..."
cat > "/etc/systemd/system/${SERVICE_NAME}.service" <<EOF
[Unit]
Description=C VPS Disk Agent
After=network.target docker.service

[Service]
Type=simple
WorkingDirectory=${INSTALL_DIR}
ExecStart=/usr/bin/python3 -m uvicorn main:app --host 0.0.0.0 --port ${PORT}
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

echo "[4/6] Liberando porta ${PORT} no ufw (se ativo)..."
if command -v ufw >/dev/null 2>&1; then
  ufw allow "${PORT}/tcp" || true
  ufw reload || true
fi

echo "[5/6] Iniciando servico..."
systemctl daemon-reload
systemctl enable "$SERVICE_NAME"
systemctl restart "$SERVICE_NAME"

echo "[6/6] Status:"
sleep 2
systemctl status "$SERVICE_NAME" --no-pager || true

IP=$(hostname -I 2>/dev/null | awk '{print $1}')
echo ""
echo "============================================"
echo " AGENTE INSTALADO"
echo " URL:  http://${IP:-SEU_IP}:${PORT}/health"
echo " Token: veja ${INSTALL_DIR}/config.py (AGENT_SECRET)"
echo ""
echo " PROXIMO PASSO no hPanel:"
echo " Firewall -> Accept TCP ${PORT} -> Anywhere"
echo ""
echo " Depois configure backend/config.py:"
echo " VPS_AGENT_URL = \"http://${IP:-31.97.167.75}:${PORT}\""
echo " VPS_AGENT_SECRET = \"<mesmo token do agent/config.py>\""
echo "============================================"
