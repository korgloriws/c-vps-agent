import os

# Token de acesso — use o MESMO valor em backend/config.py (VPS_AGENT_SECRET).
AGENT_SECRET = os.environ.get("AGENT_SECRET", "cvps_agent_7f3a9b2c1d8e4f6a")

# Porta HTTP do agente na VPS (abra no firewall Hostinger: Accept TCP desta porta).
AGENT_PORT = 9876
AGENT_HOST = "0.0.0.0"
