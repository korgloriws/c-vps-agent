# C VPS Agent

Agente na VPS em `/opt/c-vps-agent`. **Finmas nao e modificado** (continua em `/`).

## Por que /cvps/ na porta 80?

| Origem | 9876 / 8080 | Porta 80 `/cvps/` |
|--------|-------------|-------------------|
| VPS (local) | Funciona | Funciona |
| Seu PC (rede trabalho) | **Bloqueado** | **Funciona** |

O agente roda na **9876** na VPS. O nginx so encaminha `/cvps/` → agente. O Finmas em `/` nao muda.

---

## Instalacao

```bash
cd /opt/c-vps-agent
git pull
docker compose up -d --build
curl http://127.0.0.1:9876/health
```

## Proxy seguro (1 vez, nao mexe no finmas)

```bash
cd /opt/c-vps-agent
git pull
bash diagnose.sh          # se falhar, envie a saida
bash safe-nginx-install.sh
```

Se der "nginx nao encontrado":

```bash
docker ps
NGINX_CTR=nome_do_container_com_porta_80 bash safe-nginx-install.sh
```

Teste:

```bash
curl http://127.0.0.1/              # finmas (HTML)
curl http://127.0.0.1/cvps/health   # agente (JSON)
```

No PC:

```powershell
curl.exe http://31.97.167.75/cvps/health
```

## Painel local

```python
VPS_AGENT_URL = "http://31.97.167.75/cvps"
VPS_AGENT_SECRET = "cvps_agent_7f3a9b2c1d8e4f6a"
```

---

## Atualizar agente

```bash
cd /opt/c-vps-agent
git pull
docker compose up -d --build
```

## Remover proxy (se precisar)

```bash
docker exec NOME_NGINX rm /etc/nginx/conf.d/zz-cvps-agent.conf
docker exec NOME_NGINX nginx -s reload
```
