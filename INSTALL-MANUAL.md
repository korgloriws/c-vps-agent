# Instalacao manual do /cvps/ (se o script falhar)

## Por que volta HTML do Finmas?

O nginx do host manda **tudo** para `finmas-app:8080`:

```
/cvps/health  →  finmas-app  →  SPA devolve index.html  ❌
```

Precisa deste bloco **ANTES** do `location /`:

```nginx
    # C-VPS-AGENT-PROXY
    location ^~ /cvps/ {
        proxy_pass http://127.0.0.1:9876/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_read_timeout 120s;
    }
```

## Passos na VPS

```bash
# 1. Ver config do finmas
sudo grep -r "8080" /etc/nginx/sites-enabled/ /etc/nginx/conf.d/

# 2. Editar o arquivo (exemplo)
sudo nano /etc/nginx/sites-enabled/finmas
# ou: sudo nano /etc/nginx/sites-enabled/default

# 3. Colar o bloco /cvps/ ANTES de "location /"

# 4. Testar e recarregar
sudo nginx -t
sudo systemctl reload nginx

# 5. Testar NA VPS primeiro
curl http://127.0.0.1/cvps/health
# Deve ser: {"ok":true,"service":"c-vps-agent"}
```

## No PC

```powershell
curl.exe http://31.97.167.75/cvps/health
```
