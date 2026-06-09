#!/bin/bash
# Inventario SQLite + uso de disco Docker (/var/lib). Somente leitura.
# Em Docker: HOST_ROOT=/host

HOST_ROOT="${HOST_ROOT:-/}"
ROOT="${HOST_ROOT%/}"

strip_root() {
  local p="$1"
  if [ "$ROOT" != "/" ] && [[ "$p" == "$ROOT"* ]]; then
    echo "${p#$ROOT}"
  else
    echo "$p"
  fi
}

classify_kind() {
  local f="$1"
  local base
  base=$(basename "$f")
  if [[ "$f" == *backup_antes_restore* ]]; then
    echo "backup"
  elif [[ "$f" == */backups/* ]] || [[ "$f" == */backup/* ]]; then
    echo "backup"
  elif [[ "$base" == *backup* ]] || [[ "$base" == *bak* ]] || [[ "$base" == *.old ]]; then
    echo "backup"
  elif [[ "$base" == WAL ]] || [[ "$base" == *-wal ]] || [[ "$base" == *-shm ]]; then
    echo "wal"
  else
    echo "database"
  fi
}

guess_project() {
  local f="$1"
  if [[ "$f" == *finmas* ]]; then echo "finmas"
  elif [[ "$f" == *c-vps* ]]; then echo "c-vps-agent"
  elif [[ "$f" == /opt/* ]]; then echo "$(echo "$f" | cut -d/ -f3)"
  else echo "other"
  fi
}

emit_file() {
  local f="$1"
  local forced_kind="${2:-}"
  [ -f "$f" ] || return
  local size mtime kind project
  size=$(stat -c '%s' "$f" 2>/dev/null || echo 0)
  mtime=$(stat -c '%Y' "$f" 2>/dev/null || echo 0)
  if [ -n "$forced_kind" ]; then kind="$forced_kind"
  else kind=$(classify_kind "$f"); fi
  project=$(guess_project "$f")
  echo "$(strip_root "$f")|${size}|${mtime}|${project}|${kind}|$(basename "$f")"
}

echo "===DOCKER_MOUNTS==="
for c in $(docker ps -a --format '{{.Names}}' 2>/dev/null); do
  docker inspect "$c" --format '{{range .Mounts}}{{.Type}}|{{.Source}}|{{.Destination}}{{"\n"}}{{end}}' 2>/dev/null \
    | while IFS='|' read -r typ src dst; do
        [ -n "$typ" ] || continue
        echo "${c}|${typ}|$(strip_root "$src")|${dst}"
      done
done

echo "===BACKUP_DIRS==="
# Pastas de backup reais (sem listar /data inteiro)
if [ -d "$ROOT/opt/finmas/backups" ]; then
  d="$ROOT/opt/finmas/backups"
  file_count=$(find "$d" -type f 2>/dev/null | wc -l | tr -d ' ')
  total_bytes=$(du -sb "$d" 2>/dev/null | cut -f1)
  echo "$(strip_root "$d")|${file_count}|${total_bytes}|finmas"
fi
find "$ROOT/opt/finmas" -type d -name 'backup_antes_restore_*' 2>/dev/null | while read -r d; do
  file_count=$(find "$d" -type f 2>/dev/null | wc -l | tr -d ' ')
  total_bytes=$(du -sb "$d" 2>/dev/null | cut -f1)
  echo "$(strip_root "$d")|${file_count}|${total_bytes}|finmas_restore"
done

echo "===FINMAS_BACKUP_FILES==="
if [ -d "$ROOT/opt/finmas/backups" ]; then
  find "$ROOT/opt/finmas/backups" -type f 2>/dev/null | while read -r f; do emit_file "$f" backup; done
fi

echo "===SQLITE_FILES==="
if [ -d "$ROOT/opt/finmas" ]; then
  find "$ROOT/opt/finmas" -type f \( \
    -name '*.db' -o -name '*.sqlite' -o -name '*.sqlite3' \
    -o -name '*.db-*' -o -name '*.sqlite-*' \
  \) 2>/dev/null | while read -r f; do emit_file "$f"; done
fi

if [ -d "$ROOT/var/lib/docker/volumes" ]; then
  find "$ROOT/var/lib/docker/volumes" -maxdepth 8 -type f \( \
    -name '*.db' -o -name '*.sqlite' -o -name '*.sqlite3' \
  \) 2>/dev/null | head -300 | while read -r f; do emit_file "$f"; done
fi
