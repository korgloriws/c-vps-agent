"""Inventario SQLite na VPS (somente leitura)."""
from __future__ import annotations

import socket
import subprocess
from datetime import datetime, timezone
from pathlib import Path

from disk_parser import parse_section_output

DISCOVER_SCRIPT = Path(__file__).resolve().parent / "discover-sqlite.sh"


def _human_size(num_bytes: int) -> str:
    n = float(num_bytes)
    for unit in ("B", "K", "M", "G", "T"):
        if n < 1024 or unit == "T":
            if unit == "B":
                return f"{int(n)}{unit}"
            return f"{n:.1f}{unit}"
        n /= 1024
    return f"{n:.1f}T"


def _parse_sqlite_inventory(raw: str) -> dict:
    sections = parse_section_output(raw)
    files = []
    for line in sections.get("SQLITE_FILES", "").splitlines():
        if "|" not in line:
            continue
        parts = line.split("|")
        if len(parts) < 6:
            continue
        path, size_s, mtime_s, project, kind, name = parts[:6]
        try:
            size_b = int(size_s)
        except ValueError:
            size_b = 0
        try:
            mtime = int(mtime_s)
            mtime_iso = datetime.fromtimestamp(mtime, tz=timezone.utc).isoformat()
        except (ValueError, OSError):
            mtime_iso = ""
        files.append(
            {
                "path": path,
                "name": name,
                "size_bytes": size_b,
                "size": _human_size(size_b),
                "mtime": mtime_iso,
                "project": project,
                "kind": kind,
            }
        )

    backup_dirs = []
    for line in sections.get("BACKUP_DIRS", "").splitlines():
        if "|" not in line:
            continue
        path, count_s, bytes_s = line.split("|", 2)
        try:
            total_b = int(bytes_s)
            count = int(count_s)
        except ValueError:
            total_b, count = 0, 0
        backup_dirs.append(
            {
                "path": path,
                "file_count": count,
                "total_bytes": total_b,
                "total": _human_size(total_b),
            }
        )

    mounts = []
    for line in sections.get("DOCKER_MOUNTS", "").splitlines():
        if "|" not in line:
            continue
        parts = line.split("|")
        if len(parts) < 4:
            continue
        mounts.append(
            {
                "container": parts[0],
                "type": parts[1],
                "host_path": parts[2],
                "container_path": parts[3],
            }
        )

    by_project: dict[str, dict] = {}
    for f in files:
        proj = f["project"]
        bucket = by_project.setdefault(
            proj,
            {
                "project": proj,
                "files": [],
                "backup_count": 0,
                "backup_bytes": 0,
                "database_count": 0,
                "database_bytes": 0,
            },
        )
        bucket["files"].append(f)
        if f["kind"] == "backup":
            bucket["backup_count"] += 1
            bucket["backup_bytes"] += f["size_bytes"]
        elif f["kind"] == "database":
            bucket["database_count"] += 1
            bucket["database_bytes"] += f["size_bytes"]

    for proj in by_project.values():
        proj["backup_total"] = _human_size(proj["backup_bytes"])
        proj["database_total"] = _human_size(proj["database_bytes"])
        proj["files"].sort(key=lambda x: x["size_bytes"], reverse=True)

    backup_dirs.sort(key=lambda x: x["total_bytes"], reverse=True)

    return {
        "files": sorted(files, key=lambda x: x["size_bytes"], reverse=True),
        "backup_dirs": backup_dirs,
        "docker_mounts": mounts,
        "projects": sorted(by_project.values(), key=lambda x: x["project"]),
        "summary": {
            "total_files": len(files),
            "backup_files": sum(1 for f in files if f["kind"] == "backup"),
            "database_files": sum(1 for f in files if f["kind"] == "database"),
            "total_backup_bytes": sum(f["size_bytes"] for f in files if f["kind"] == "backup"),
            "total_backup": _human_size(
                sum(f["size_bytes"] for f in files if f["kind"] == "backup")
            ),
        },
    }


def run_sqlite_inventory() -> dict:
    if not DISCOVER_SCRIPT.is_file():
        raise RuntimeError(f"discover-sqlite.sh nao encontrado em {DISCOVER_SCRIPT}")

    result = subprocess.run(
        ["bash", str(DISCOVER_SCRIPT)],
        capture_output=True,
        text=True,
        timeout=120,
        check=False,
    )
    raw = result.stdout
    if result.returncode != 0 and not raw.strip():
        raise RuntimeError(result.stderr.strip() or f"discover falhou (exit {result.returncode})")

    report = _parse_sqlite_inventory(raw)
    report["source"] = "agent"
    report["hostname"] = socket.gethostname()
    return report
