#!/bin/bash
# Detalhamento de /var/lib (Docker, logs, arquivos grandes). Somente leitura.
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

echo "===VAR_LIB_TOP==="
if [ -d "$ROOT/var/lib" ]; then
  total=$(du -sb "$ROOT/var/lib" 2>/dev/null | cut -f1)
  echo "total|/var/lib|${total:-0}"
  du -sb "$ROOT/var/lib"/* 2>/dev/null | sort -rn | while read -r sz path; do
    [ -n "$sz" ] || continue
    echo "$(basename "$path")|$(strip_root "$path")|${sz}"
  done
fi

echo "===DOCKER_STORAGE==="
if [ -d "$ROOT/var/lib/docker" ]; then
  total=$(du -sb "$ROOT/var/lib/docker" 2>/dev/null | cut -f1)
  echo "total|$(strip_root "$ROOT/var/lib/docker")|${total:-0}"
  for d in overlay2 containers volumes image buildkit network; do
    p="$ROOT/var/lib/docker/$d"
    [ -d "$p" ] || continue
    sz=$(du -sb "$p" 2>/dev/null | cut -f1)
    echo "${d}|$(strip_root "$p")|${sz:-0}"
  done
fi

echo "===DOCKER_SYSTEM_DF==="
docker system df 2>/dev/null || echo "DOCKER_NOT_AVAILABLE"

echo "===DOCKER_IMAGES==="
docker images --format '{{.Repository}}:{{.Tag}}|{{.Size}}|{{.ID}}' 2>/dev/null | head -40

echo "===DOCKER_VOLUME_SIZES==="
docker volume ls -q 2>/dev/null | while read -r vol; do
  [ -n "$vol" ] || continue
  mp=$(docker volume inspect "$vol" --format '{{.Mountpoint}}' 2>/dev/null)
  [ -n "$mp" ] || continue
  host_mp="$mp"
  [[ "$mp" != "$ROOT"* ]] && [ "$ROOT" != "/" ] && host_mp="$ROOT$mp"
  sz=$(du -sb "$host_mp" 2>/dev/null | cut -f1)
  echo "${vol}|$(strip_root "$host_mp")|${sz:-0}"
done

echo "===DOCKER_CONTAINER_LOGS==="
if [ -d "$ROOT/var/lib/docker/containers" ]; then
  docker ps -a --no-trunc --format '{{.ID}}|{{.Names}}' 2>/dev/null > /tmp/cvps_cids.$$ || true
  find "$ROOT/var/lib/docker/containers" -maxdepth 2 -name '*-json.log' 2>/dev/null | while read -r logf; do
    cid_dir=$(basename "$(dirname "$logf")")
    cid12="${cid_dir:0:12}"
    name="$cid12"
    if [ -f /tmp/cvps_cids.$$ ]; then
      match=$(grep "^${cid_dir}|" /tmp/cvps_cids.$$ 2>/dev/null | head -1)
      [ -z "$match" ] && match=$(grep "^${cid12}" /tmp/cvps_cids.$$ 2>/dev/null | head -1)
      if [ -n "$match" ]; then
        name=$(echo "$match" | cut -d'|' -f2)
      fi
    fi
    sz=$(stat -c '%s' "$logf" 2>/dev/null || echo 0)
    echo "${name}|$(strip_root "$logf")|${sz}"
  done
  rm -f /tmp/cvps_cids.$$
fi

echo "===LARGE_FILES==="
find "$ROOT/var/lib" -xdev -type f -size +50M 2>/dev/null | head -50 | while read -r f; do
  sz=$(stat -c '%s' "$f" 2>/dev/null || echo 0)
  echo "$(strip_root "$f")|${sz}"
done
