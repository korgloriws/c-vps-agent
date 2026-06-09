"""Detalhamento de /var/lib na VPS (somente leitura)."""
from __future__ import annotations

import socket
import subprocess
from pathlib import Path

from disk_parser import parse_docker_images, parse_section_output

DISCOVER_SCRIPT = Path(__file__).resolve().parent / "discover-varlib.sh"


def _human_size(num_bytes: int) -> str:
    n = float(num_bytes)
    for unit in ("B", "K", "M", "G", "T"):
        if n < 1024 or unit == "T":
            if unit == "B":
                return f"{int(n)}{unit}"
            return f"{n:.1f}{unit}"
        n /= 1024
    return f"{n:.1f}T"


def _parse_size_rows(block: str, name_key: str = "name") -> list[dict]:
    rows = []
    for line in block.strip().splitlines():
        if "|" not in line:
            continue
        parts = line.split("|")
        if len(parts) < 3:
            continue
        name, path, bytes_s = parts[0], parts[1], parts[2]
        try:
            total_b = int(bytes_s)
        except ValueError:
            total_b = 0
        rows.append(
            {
                name_key: name,
                "path": path,
                "total_bytes": total_b,
                "total": _human_size(total_b),
            }
        )
    return rows


def _parse_varlib_report(raw: str) -> dict:
    sections = parse_section_output(raw)

    var_lib_top = _parse_size_rows(sections.get("VAR_LIB_TOP", ""))
    docker_storage = _parse_size_rows(sections.get("DOCKER_STORAGE", ""))

    docker_volumes = []
    for line in sections.get("DOCKER_VOLUME_SIZES", "").splitlines():
        if "|" not in line:
            continue
        vol, path, bytes_s = line.split("|", 2)
        try:
            total_b = int(bytes_s)
        except ValueError:
            total_b = 0
        docker_volumes.append(
            {
                "volume": vol,
                "path": path,
                "total_bytes": total_b,
                "total": _human_size(total_b),
            }
        )
    docker_volumes.sort(key=lambda x: x["total_bytes"], reverse=True)

    container_logs = []
    for line in sections.get("DOCKER_CONTAINER_LOGS", "").splitlines():
        if "|" not in line:
            continue
        name, path, bytes_s = line.split("|", 2)
        try:
            total_b = int(bytes_s)
        except ValueError:
            total_b = 0
        container_logs.append(
            {
                "container": name,
                "path": path,
                "total_bytes": total_b,
                "total": _human_size(total_b),
            }
        )
    container_logs.sort(key=lambda x: x["total_bytes"], reverse=True)

    large_files = []
    for line in sections.get("LARGE_FILES", "").splitlines():
        if "|" not in line:
            continue
        path, bytes_s = line.split("|", 1)
        try:
            total_b = int(bytes_s)
        except ValueError:
            total_b = 0
        large_files.append(
            {
                "path": path,
                "total_bytes": total_b,
                "total": _human_size(total_b),
            }
        )
    large_files.sort(key=lambda x: x["total_bytes"], reverse=True)

    var_total = next((r["total_bytes"] for r in var_lib_top if r["name"] == "total"), 0)
    docker_total = next((r["total_bytes"] for r in docker_storage if r["name"] == "total"), 0)
    logs_total = sum(r["total_bytes"] for r in container_logs)

    return {
        "var_lib_top": [r for r in var_lib_top if r["name"] != "total"],
        "docker_storage": [r for r in docker_storage if r["name"] != "total"],
        "docker_system_df": sections.get("DOCKER_SYSTEM_DF", "").strip(),
        "docker_images": parse_docker_images(sections.get("DOCKER_IMAGES", "")),
        "docker_volumes": docker_volumes,
        "container_logs": container_logs,
        "large_files": large_files,
        "summary": {
            "var_lib_total_bytes": var_total,
            "var_lib_total": _human_size(var_total),
            "docker_total_bytes": docker_total,
            "docker_total": _human_size(docker_total),
            "container_logs_bytes": logs_total,
            "container_logs_total": _human_size(logs_total),
            "large_file_count": len(large_files),
        },
    }


def run_varlib_scan() -> dict:
    if not DISCOVER_SCRIPT.is_file():
        raise RuntimeError(f"discover-varlib.sh nao encontrado em {DISCOVER_SCRIPT}")

    result = subprocess.run(
        ["bash", str(DISCOVER_SCRIPT)],
        capture_output=True,
        text=True,
        timeout=300,
        check=False,
    )
    raw = result.stdout
    if result.returncode != 0 and not raw.strip():
        raise RuntimeError(result.stderr.strip() or f"scan var/lib falhou (exit {result.returncode})")

    report = _parse_varlib_report(raw)
    report["source"] = "agent"
    report["hostname"] = socket.gethostname()
    return report
