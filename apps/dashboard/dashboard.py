"""Log resource usage of systemd services and docker containers, and serve a dashboard of it.

Every INTERVAL seconds, the counters systemd keeps for each running unit are appended
to live.csv. Rows from previous days (utc) move to <date>.parquet.
"""

import http.client
import json
import mimetypes
import os
import socket
import subprocess
import threading
import time
from datetime import UTC, date, datetime, timedelta
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

import polars as pl

DATA = Path(os.environ["STATE_DIRECTORY"])
LIVE = DATA / "live.csv"
# url path -> file served there. the nix module builds style.css next to this file
PAGES = {
    "/": Path(__file__).with_name("index.html"),
    "/style.css": Path(__file__).with_name("style.css"),
}
INTERVAL = 15

COUNTERS = [
    "CPUUsageNSec",
    "IOReadBytes",
    "IOWriteBytes",
    "IPIngressBytes",
    "IPEgressBytes",
]
GAUGES = ["MemoryCurrent", "TasksCurrent"]
SCHEMA = pl.Schema(
    {"ts": pl.Datetime("ms", "UTC"), "unit": pl.String, "name": pl.String}
    | dict.fromkeys(COUNTERS + GAUGES, pl.Int64)
)

# held while appending to or reading the live csv
lock = threading.Lock()


class DockerConnection(http.client.HTTPConnection):
    def connect(self) -> None:
        self.sock = socket.socket(socket.AF_UNIX)
        self.sock.connect("/run/docker.sock")


def container_names() -> dict[str, str]:
    try:
        connection = DockerConnection("localhost")
        connection.request("GET", "/containers/json")
        containers = json.load(connection.getresponse())
    except OSError:
        return {}

    return {f"docker-{c['Id']}.scope": c["Names"][0][1:] for c in containers}


def sample(ts: datetime) -> pl.DataFrame:
    shown = subprocess.run(
        ["systemctl", "show", "--state=running", "*.service", "docker-*.scope"]
        + ["--property", ",".join(["Id", *COUNTERS, *GAUGES])],
        capture_output=True,
        text=True,
        check=True,
    ).stdout
    names = container_names()

    def row(block: str) -> dict:
        props = dict(line.split("=", 1) for line in block.splitlines())
        unit = props.pop("Id")
        # systemd prints "[not set]" and the like for missing values
        values = {
            k: int(v) if v.isdigit() and int(v) < 2**63 else None
            for k, v in props.items()
        }
        return {
            "ts": ts,
            "unit": unit,
            "name": names.get(unit, unit.removesuffix(".service")),
        } | values

    return pl.DataFrame([row(b) for b in shown.strip().split("\n\n")], schema=SCHEMA)


def read_live() -> pl.DataFrame:
    with lock:
        return pl.read_csv(LIVE, schema=SCHEMA) if LIVE.exists() else SCHEMA.to_frame()


def archive(today: date) -> None:
    live = read_live()
    day = pl.col("ts").dt.date()

    for (d,), rows in live.filter(day < today).group_by(day):
        rows.write_parquet(DATA / f"{d}.parquet")

    with lock:
        live.filter(day >= today).write_csv(LIVE)


def usage(hours: float) -> str:
    """Per-second rates of the counters and the gauges, in about 300 buckets per unit."""
    seconds = pl.col("ts").diff().dt.total_milliseconds() / 1000
    rates = [
        pl.when(pl.col(c).diff() >= 0)
        .then(pl.col(c).diff() / seconds)
        .over("unit", order_by="ts")
        .alias(c)
        for c in COUNTERS
    ]
    since = datetime.now(UTC) - timedelta(hours=hours)
    every = max(INTERVAL, int(hours * 3600 / 300))
    stored = (
        [pl.scan_parquet(DATA / "*.parquet")] if any(DATA.glob("*.parquet")) else []
    )

    return (
        pl.concat([*stored, read_live().lazy()])
        .filter(pl.col("ts") >= since)
        .select("ts", "name", *rates, *GAUGES)
        .sort("ts")
        # by name rather than unit, so a recreated container stays one series
        .group_by_dynamic("ts", every=f"{every}s", group_by="name")
        .agg(pl.all().mean())
        .with_columns(pl.col("ts").dt.epoch("ms"))
        .collect()
        .write_json()
    )


class Handler(BaseHTTPRequestHandler):
    def do_GET(self) -> None:
        url = urlparse(self.path)

        if url.path == "/api/usage":
            body = usage(float(parse_qs(url.query)["hours"][0])).encode()
            kind = "application/json"
        elif page := PAGES.get(url.path):
            body, kind = page.read_bytes(), mimetypes.guess_type(page)[0]
        else:
            return self.send_error(404)

        self.send_response(200)
        self.send_header("Content-Type", kind or "application/octet-stream")
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format: str, *args: object) -> None:
        pass


def main() -> None:
    server = ThreadingHTTPServer(("localhost", int(os.environ["PORT"])), Handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()

    # collect in the main thread, so a failure exits and systemd restarts the service
    day = None

    while True:
        now = datetime.now(UTC)

        if now.date() != day:
            day = now.date()
            archive(day)

        rows = sample(now)

        with lock, LIVE.open("ab") as f:
            rows.write_csv(f, include_header=not f.tell())

        time.sleep(INTERVAL - time.time() % INTERVAL)


if __name__ == "__main__":
    main()
