"""Agente HTTP na VPS — expoe scan de disco sem SSH do PC local."""
from fastapi import Depends, FastAPI, Header, HTTPException

from config import AGENT_HOST, AGENT_PORT, AGENT_SECRET
from scanner import run_disk_scan
from sqlite_scanner import run_sqlite_inventory

app = FastAPI(title="C VPS Agent", docs_url=None, redoc_url=None)


def verify_token(authorization: str | None = Header(default=None)) -> None:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(401, "Token ausente. Use: Authorization: Bearer <secret>")
    token = authorization.removeprefix("Bearer ").strip()
    if token != AGENT_SECRET:
        raise HTTPException(403, "Token invalido")


@app.get("/health")
def health():
    return {"ok": True, "service": "c-vps-agent"}


@app.get("/disk-detail")
def disk_detail(_: None = Depends(verify_token)):
    try:
        return run_disk_scan()
    except Exception as exc:
        raise HTTPException(500, f"Scan falhou: {exc}") from exc


@app.get("/sqlite-inventory")
def sqlite_inventory(_: None = Depends(verify_token)):
    try:
        return run_sqlite_inventory()
    except Exception as exc:
        raise HTTPException(500, f"Inventario SQLite falhou: {exc}") from exc


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host=AGENT_HOST, port=AGENT_PORT)
