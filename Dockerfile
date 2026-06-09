FROM python:3.11-slim-bookworm

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash git procps docker.io \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY main.py config.py scanner.py sqlite_scanner.py varlib_scanner.py disk_parser.py scan.sh discover-sqlite.sh discover-varlib.sh ./
RUN chmod +x scan.sh discover-sqlite.sh discover-varlib.sh

ENV HOST_ROOT=/host
EXPOSE 9876

CMD ["python", "-m", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "9876"]
