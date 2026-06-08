"""Executa scan de disco localmente na VPS."""
from __future__ import annotations

import socket
import subprocess
from pathlib import Path

from disk_parser import parse_disk_report

SCAN_SCRIPT = Path(__file__).resolve().parent / "scan.sh"


def run_disk_scan() -> dict:
    if not SCAN_SCRIPT.is_file():
        raise RuntimeError(f"scan.sh nao encontrado em {SCAN_SCRIPT}")

    result = subprocess.run(
        ["bash", str(SCAN_SCRIPT)],
        capture_output=True,
        text=True,
        timeout=120,
        check=False,
    )
    raw = result.stdout
    if result.returncode != 0 and not raw.strip():
        raise RuntimeError(result.stderr.strip() or f"scan falhou (exit {result.returncode})")

    report = parse_disk_report(raw)
    report["source"] = "agent"
    report["hostname"] = socket.gethostname()
    report["agent_host"] = socket.gethostname()
    return report
