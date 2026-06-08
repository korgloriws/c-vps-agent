#!/bin/bash
# Coleta uso de disco, Docker e projetos na VPS.
# Em Docker: HOST_ROOT=/host (volume /:/host:ro)
# Nativo:    HOST_ROOT=/ (padrao)

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

echo "===DF==="
if [ "$ROOT" = "/" ]; then
  df -hT -x tmpfs -x devtmpfs 2>/dev/null | tail -n +2
else
  for m in "$ROOT" "$ROOT/var" "$ROOT/opt" "$ROOT/home"; do
    [ -d "$m" ] || continue
    df -hT "$m" 2>/dev/null | tail -n +2 | while read -r line; do
      echo "$line" | awk -v r="$ROOT" '{gsub(r, "", $NF); if($NF=="") $NF="/"; print}'
    done
  done
fi

echo "===DU_ROOT==="
du -xhd1 "$ROOT" 2>/dev/null | sort -hr | head -20 | while IFS=$'\t' read -r size path; do
  echo -e "${size}\t$(strip_root "$path")"
done

echo "===DU_VAR==="
[ -d "$ROOT/var" ] && du -xhd1 "$ROOT/var" 2>/dev/null | sort -hr | head -15 | while IFS=$'\t' read -r size path; do
  echo -e "${size}\t$(strip_root "$path")"
done

echo "===DU_HOME==="
[ -d "$ROOT/home" ] && du -xhd1 "$ROOT/home" 2>/dev/null | sort -hr | head -10 | while IFS=$'\t' read -r size path; do
  echo -e "${size}\t$(strip_root "$path")"
done

echo "===DOCKER_DF==="
docker system df 2>/dev/null || echo "DOCKER_NOT_AVAILABLE"

echo "===DOCKER_IMAGES==="
docker images --format '{{.Repository}}:{{.Tag}}|{{.Size}}|{{.ID}}' 2>/dev/null | head -25

echo "===DOCKER_PS==="
docker ps -a --format '{{.Names}}|{{.Image}}|{{.Status}}|{{.Size}}' 2>/dev/null

echo "===COMPOSE==="
for base in "$ROOT/opt" "$ROOT/home" "$ROOT/var/www" "$ROOT/srv" "$ROOT/root"; do
  [ -d "$base" ] || continue
  find "$base" -maxdepth 5 \( -name docker-compose.yml -o -name compose.yml \) 2>/dev/null
done | head -25 | while read -r f; do
  strip_root "$f"
done

echo "===PROJECTS==="
for base in "$ROOT/opt" "$ROOT/home" "$ROOT/var/www" "$ROOT/srv" "$ROOT/root"; do
  [ -d "$base" ] || continue
  for gitdir in $(find "$base" -maxdepth 5 -name .git -type d 2>/dev/null | head -20); do
    dir=$(dirname "$gitdir")
    size=$(du -sh "$dir" 2>/dev/null | cut -f1)
    ver=$(git -C "$dir" describe --tags --always 2>/dev/null || echo "-")
    branch=$(git -C "$dir" branch --show-current 2>/dev/null || echo "-")
    commits=$(git -C "$dir" rev-list --count HEAD 2>/dev/null || echo "0")
    echo "$(strip_root "$dir")|${size}|${ver}|${branch}|${commits}"
  done
done

echo "===COMPOSE_SIZE==="
for base in "$ROOT/opt" "$ROOT/home" "$ROOT/var/www" "$ROOT/srv" "$ROOT/root"; do
  [ -d "$base" ] || continue
  for f in $(find "$base" -maxdepth 5 \( -name docker-compose.yml -o -name compose.yml \) 2>/dev/null | head -25); do
    dir=$(dirname "$f")
    size=$(du -sh "$dir" 2>/dev/null | cut -f1)
    name=$(basename "$dir")
    echo "$(strip_root "$dir")|${name}|${size}|compose"
  done
done
