#!/bin/bash
# /cvps/ em TODOS os server {} da porta 80 (IP e dominio).
set -e

MARKER="# C-VPS-AGENT-PROXY"
BLOCK='
    # C-VPS-AGENT-PROXY
    location ^~ /cvps/ {
        proxy_pass http://127.0.0.1:9876/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_read_timeout 120s;
    }
'

echo "=== Diagnostico ==="
echo "Sites enabled:"
ls -la /etc/nginx/sites-enabled/
echo ""
echo "default_server:"
grep -rn "default_server" /etc/nginx/sites-enabled/ /etc/nginx/conf.d/ 2>/dev/null || echo "(nenhum marcado)"
echo ""
echo "server_name + listen 80:"
grep -rn "server_name\|listen.*80" /etc/nginx/sites-enabled/ 2>/dev/null
echo ""
echo "Bloco cvps atual:"
grep -rn "cvps" /etc/nginx/sites-enabled/ /etc/nginx/conf.d/ 2>/dev/null || echo "(nao encontrado)"
echo ""

mkdir -p /etc/nginx/backups-cvps
mv /etc/nginx/sites-enabled/*.bak* /etc/nginx/backups-cvps/ 2>/dev/null || true

python3 <<'PY'
import re, glob

MARKER = "# C-VPS-AGENT-PROXY"
BLOCK = """
    # C-VPS-AGENT-PROXY
    location ^~ /cvps/ {
        proxy_pass http://127.0.0.1:9876/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_read_timeout 120s;
    }
"""

def patch_file(path):
    text = open(path, encoding="utf-8").read()
    if "listen" not in text or "80" not in text:
        return False
    if MARKER in text:
        # remover bloco antigo para reinserir limpo
        text = re.sub(
            r"\n\s*# C-VPS-AGENT-PROXY.*?proxy_read_timeout 120s;\n\s*\}\n",
            "\n",
            text,
            flags=re.DOTALL,
        )
    servers = list(re.finditer(r"server\s*\{", text))
    if not servers:
        return False
    # inserir em cada server { } que tenha listen 80
    offset = 0
    new_text = text
    for m in servers:
        start = m.end() + offset
        chunk = new_text[start : start + 400]
        if "80" not in chunk[:200]:
            continue
        new_text = new_text[:start] + BLOCK + new_text[start:]
        offset += len(BLOCK)
    if new_text == text:
        return False
    open(path, encoding="utf-8").write(new_text)
    print(f"Patch: {path}")
    return True

changed = False
for pattern in ("/etc/nginx/sites-enabled/*", "/etc/nginx/conf.d/*.conf"):
    for path in glob.glob(pattern):
        if patch_file(path):
            changed = True

if not changed:
    print("Nenhum arquivo alterado — envie: cat /etc/nginx/sites-enabled/*")
    exit(1)
PY

nginx -t
systemctl reload nginx

echo ""
echo "=== Teste ==="
echo -n "127.0.0.1/cvps/health: "
curl -s http://127.0.0.1/cvps/health | head -c 80
echo ""
echo -n "IP/cvps/health: "
curl -s -H "Host: 31.97.167.75" http://127.0.0.1/cvps/health | head -c 80
echo ""
