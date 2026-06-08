# C VPS Agent

Agente HTTP na VPS — escaneia disco, Docker e projetos (ex.: `/opt/finmas`).  
O painel local chama por HTTP — **nao precisa SSH do seu PC**.

Deploy igual ao **finmas**: GitHub + `git pull` + `docker compose`.

---

## 1. Criar repositorio no GitHub

Suba **o conteudo desta pasta `agent/`** como raiz do repo (ex.: `c-vps-agent`).

No seu PC:

```powershell
cd c:\Users\mateus.rodrigues\Downloads\C_vps\agent
git init
git add .
git commit -m "agente c-vps"
git remote add origin https://github.com/SEU_USUARIO/c-vps-agent.git
git push -u origin main
```

---

## 2. Primeira instalacao na VPS

No **terminal do navegador** (hPanel → VPS → Browser terminal):

```bash
mkdir -p /opt/c-vps-agent
cd /opt/c-vps-agent
git clone https://github.com/SEU_USUARIO/c-vps-agent.git .
chmod +x deploy.sh scan.sh
docker compose up -d --build
```

**Firewall hPanel:** Accept · TCP · **9876** · Anywhere

Teste:

```bash
curl http://127.0.0.1:9876/health
```

---

## 3. Atualizar (igual ao finmas)

```bash
cd /opt/c-vps-agent
git pull
docker compose build
docker compose down
docker compose up -d
```

Ou use o script:

```bash
cd /opt/c-vps-agent
bash deploy.sh
```

Mesmo padrao do finmas:

```bash
cd /opt/finmas
git pull
docker-compose build
docker-compose down
docker-compose up -d
```

---

## 4. Painel local

`backend/config.py`:

```python
VPS_AGENT_URL = "http://31.97.167.75:9876"
VPS_AGENT_SECRET = "cvps_agent_7f3a9b2c1d8e4f6a"
```

Reinicie o backend local.

---

## O que o agente enxerga

| Item | Exemplo na sua VPS |
|------|-------------------|
| Sistema finmas | `/opt/finmas` (compose + git) |
| Containers | via Docker socket |
| Imagens / versoes | tags Docker + git describe |
| Pastas grandes | `/var`, `/opt`, etc. |

---

## SSH?

- **Deploy:** nao precisa SSH do PC — so terminal do hPanel + git (como finmas).
- **Painel local:** chama o agente por HTTP na porta 9876.
- **SSH do PC:** opcional; na rede do trabalho costuma estar bloqueado.

---

## Comandos uteis

```bash
docker compose -f /opt/c-vps-agent/docker-compose.yml logs -f
docker compose -f /opt/c-vps-agent/docker-compose.yml ps
curl -H "Authorization: Bearer cvps_agent_7f3a9b2c1d8e4f6a" http://127.0.0.1:9876/disk-detail
```

## Instalacao sem Docker (alternativa)

```bash
bash install.sh   # usa systemd + python nativo
```
