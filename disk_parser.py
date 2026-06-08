"""Parser do relatorio de disco (compartilhado com o backend local)."""
from __future__ import annotations

import re
from typing import Any


def parse_du_lines(block: str) -> list[dict[str, str]]:
    rows = []
    for line in block.strip().splitlines():
        line = line.strip()
        if not line:
            continue
        parts = line.split("\t", 1)
        if len(parts) == 2:
            size, path = parts[0].strip(), parts[1].strip()
        else:
            match = re.match(r"^([\d.,]+\s*\S+)\s+(.+)$", line)
            if not match:
                continue
            size, path = match.group(1), match.group(2)
        rows.append({"size": size.strip(), "path": path})
    return rows


def parse_section_output(raw: str) -> dict[str, str]:
    sections: dict[str, str] = {}
    current = None
    buf: list[str] = []
    for line in raw.splitlines():
        if line.startswith("===") and line.endswith("==="):
            if current:
                sections[current] = "\n".join(buf).strip()
            current = line.strip("=").strip()
            buf = []
        else:
            buf.append(line)
    if current:
        sections[current] = "\n".join(buf).strip()
    return sections


def parse_df(block: str) -> list[dict[str, str]]:
    rows = []
    for line in block.strip().splitlines():
        parts = line.split()
        if len(parts) < 7:
            continue
        rows.append(
            {
                "filesystem": parts[0],
                "type": parts[1],
                "size": parts[2],
                "used": parts[3],
                "avail": parts[4],
                "use_percent": parts[5],
                "mount": parts[6],
            }
        )
    return rows


def parse_docker_images(block: str) -> list[dict[str, str]]:
    rows = []
    for line in block.strip().splitlines():
        if "|" not in line:
            continue
        repo_tag, size, img_id = line.split("|", 2)
        rows.append({"image": repo_tag, "size": size, "id": img_id[:12]})
    return rows


def parse_docker_ps(block: str) -> list[dict[str, str]]:
    rows = []
    for line in block.strip().splitlines():
        if "|" not in line:
            continue
        parts = line.split("|")
        if len(parts) < 3:
            continue
        rows.append(
            {
                "name": parts[0],
                "image": parts[1],
                "status": parts[2],
                "size": parts[3] if len(parts) > 3 else "—",
            }
        )
    return rows


def parse_projects(block: str) -> list[dict[str, Any]]:
    rows = []
    for line in block.strip().splitlines():
        if "|" not in line:
            continue
        parts = line.split("|")
        if len(parts) < 5:
            continue
        path, size, version, branch, commits = parts[:5]
        rows.append(
            {
                "path": path,
                "size": size,
                "version": version,
                "branch": branch,
                "commits": int(commits) if commits.isdigit() else commits,
                "type": "git",
            }
        )
    return rows


def parse_compose_sizes(block: str) -> list[dict[str, Any]]:
    rows = []
    for line in block.strip().splitlines():
        if "|" not in line:
            continue
        path, name, size, kind = line.split("|", 3)
        rows.append(
            {
                "path": path,
                "name": name,
                "size": size,
                "type": kind,
                "version": "—",
                "branch": "—",
            }
        )
    return rows


def merge_systems(
    git_projects: list[dict], compose_projects: list[dict]
) -> list[dict[str, Any]]:
    by_path: dict[str, dict] = {}
    for p in compose_projects:
        by_path[p["path"]] = {**p}
    for p in git_projects:
        if p["path"] in by_path:
            by_path[p["path"]].update(
                {
                    "version": p["version"],
                    "branch": p["branch"],
                    "commits": p.get("commits"),
                    "type": "compose+git",
                }
            )
        else:
            by_path[p["path"]] = {**p}
    return sorted(by_path.values(), key=lambda x: x["path"])


def parse_disk_report(raw: str) -> dict[str, Any]:
    sections = parse_section_output(raw)
    git_projects = parse_projects(sections.get("PROJECTS", ""))
    compose_projects = parse_compose_sizes(sections.get("COMPOSE_SIZE", ""))
    systems = merge_systems(git_projects, compose_projects)

    return {
        "filesystems": parse_df(sections.get("DF", "")),
        "directories_root": parse_du_lines(sections.get("DU_ROOT", "")),
        "directories_var": parse_du_lines(sections.get("DU_VAR", "")),
        "directories_home": parse_du_lines(sections.get("DU_HOME", "")),
        "docker_summary": sections.get("DOCKER_DF", "").strip(),
        "docker_images": parse_docker_images(sections.get("DOCKER_IMAGES", "")),
        "docker_containers": parse_docker_ps(sections.get("DOCKER_PS", "")),
        "compose_files": [
            line.strip()
            for line in sections.get("COMPOSE", "").splitlines()
            if line.strip()
        ],
        "systems": systems,
    }
