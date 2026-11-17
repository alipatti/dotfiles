"""Log resource usage of systemd services and docker containers, and serve a dashboard of it.

Every INTERVAL seconds, the counters systemd keeps for each running unit are appended
to live.csv. Rows from previous days (utc) move to <date>.parquet.
"""

import http.client
import json
import mimetypes
import os
import pwd
import socket
import subprocess
import threading
import time
from collections import Counter
from datetime import UTC, date, datetime, timedelta
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from itertools import zip_longest
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
INTERVAL = 60

COUNTERS = [
    "CPUUsageNSec",
    "IOReadBytes",
    "IOWriteBytes",
    "IPIngressBytes",
    "IPEgressBytes",
]
GAUGES = ["MemoryCurrent", "TasksCurrent"]
# from the unit's memory.stat, not systemd: page cache it hasn't used lately, which the
# kernel frees first. MemoryCurrent minus this is the working set, as in docker stats
INACTIVE_FILE = "MemoryInactiveFile"
# from nvidia-smi: vram of the unit's compute processes (cuda etc., not graphics)
GPU_MEMORY = "GPUMemoryUsed"
SCHEMA = pl.Schema(
    {"ts": pl.Datetime("ms", "UTC"), "unit": pl.String, "name": pl.String}
    | dict.fromkeys([*COUNTERS, *GAUGES, INACTIVE_FILE, GPU_MEMORY], pl.Int64)
)

# the metrics the page charts, which also pick the units shown
CHARTED = [*COUNTERS, "MemoryWorkingSet", GPU_MEMORY]

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


def show(*units: str) -> list[dict[str, str]]:
    """The counters systemd keeps for `units`, which can be patterns."""
    shown = subprocess.run(
        [
            "systemctl",
            "show",
            *units,
            "--property",
            ",".join(["Id", "ControlGroup", *COUNTERS, *GAUGES]),
        ],
        capture_output=True,
        text=True,
        check=True,
    ).stdout
    return [
        dict(line.split("=", 1) for line in block.splitlines())
        for block in shown.split("\n\n")
        if block.strip()
    ]


def inactive_file(cgroup: str) -> int | None:
    try:
        stat = Path(f"/sys/fs/cgroup{cgroup}/memory.stat").read_text()
    except OSError:
        return None

    return next(
        int(line.split()[1])
        for line in stat.splitlines()
        if line.startswith("inactive_file ")
    )


def gpu_memory() -> Counter[str]:
    """Bytes of vram used by compute processes, by their cgroup."""
    try:
        listing = subprocess.run(
            ["nvidia-smi", "--query-compute-apps=pid,used_memory"]
            + ["--format=csv,noheader,nounits"],
            capture_output=True,
            text=True,
            check=True,
        ).stdout
    except (OSError, subprocess.CalledProcessError):
        return Counter()

    used = Counter()

    for line in listing.splitlines():
        pid, mib = line.split(", ")
        cgroup = Path(f"/proc/{pid}/cgroup")

        # the process may have exited since, and memory may read "[N/A]"
        if cgroup.exists() and mib.isdigit():
            used[cgroup.read_text().strip().removeprefix("0::")] += int(mib) * 2**20

    return used


def display_name(unit: str, containers: dict[str, str]) -> str:
    if unit.startswith("user-"):
        uid = int(unit.removeprefix("user-").removesuffix(".slice"))

        try:
            return pwd.getpwuid(uid).pw_name
        except KeyError:
            return unit

    return containers.get(unit, unit.removesuffix(".service"))


def sample(ts: datetime) -> pl.DataFrame:
    # slices aren't "running", so they're asked for separately
    units = show("--state=running", "*.service", "docker-*.scope") + show(
        "user-*.slice"
    )
    containers = container_names()
    vram = gpu_memory()

    def row(props: dict[str, str]) -> dict:
        unit = props.pop("Id")
        cgroup = props.pop("ControlGroup")
        # systemd prints "[not set]" and the like for missing values
        values = {
            k: int(v) if v.isdigit() and int(v) < 2**63 else None
            for k, v in props.items()
        }
        return {
            "ts": ts,
            "unit": unit,
            "name": display_name(unit, containers),
            INACTIVE_FILE: inactive_file(cgroup),
            GPU_MEMORY: sum(
                used
                for path, used in vram.items()
                if path == cgroup or path.startswith(f"{cgroup}/")
            ),
        } | values

    # a user's slice holds their user@ service and login sessions, so skip the former
    return pl.DataFrame(
        [row(u) for u in units if not u["Id"].startswith("user@")],
        schema=SCHEMA,
    )


def read_live() -> pl.DataFrame:
    with lock:
        if not LIVE.exists():
            return SCHEMA.to_frame()

        live = pl.read_csv(LIVE, schema_overrides=SCHEMA)

    # a csv from before a column was added lacks it, until archive() rewrites the file
    return pl.concat([SCHEMA.to_frame(), live], how="diagonal_relaxed")


def archive(today: date) -> None:
    live = read_live()
    day = pl.col("ts").dt.date()

    for (d,), rows in live.filter(day < today).group_by(day):
        rows.write_parquet(DATA / f"{d}.parquet")

    with lock:
        live.filter(day >= today).write_csv(LIVE)


def usage(hours: float, every: int, top: int) -> str:
    """
    The charted metrics (counters as per-second rates) averaged over every `every`
    minutes, for `top` units: each metric's highest, then each's second highest, ...
    """
    seconds = pl.col("ts").diff().dt.total_milliseconds() / 1000
    rates = [
        # a counter that went down was reset, by a restart of its unit
        pl.when((pl.col(c).diff() >= 0) & (seconds > 0))
        .then(pl.col(c).diff() / seconds)
        .over("unit", order_by="ts")
        .alias(c)
        for c in COUNTERS
    ]
    working_set = pl.col("MemoryCurrent") - pl.col(INACTIVE_FILE)
    since = datetime.now(UTC) - timedelta(hours=hours)
    stored = (
        [pl.scan_parquet(DATA / "*.parquet", schema=SCHEMA, missing_columns="insert")]
        if any(DATA.glob("*.parquet"))
        else []
    )

    buckets = (
        pl.concat([*stored, read_live().lazy()])
        .filter(pl.col("ts") >= since)
        .select("ts", "name", *rates, working_set.alias("MemoryWorkingSet"), GPU_MEMORY)
        .sort("ts")
        # by name rather than unit, so a recreated container stays one series
        .group_by_dynamic("ts", every=f"{every}m", group_by="name")
        .agg(pl.all().mean())
        .collect()
    )

    totals = buckets.group_by("name").agg(pl.col(CHARTED).sum())
    rankings = [
        totals.filter(pl.col(m) > 0).sort(m, descending=True)["name"] for m in CHARTED
    ]
    ranked = (name for names in zip_longest(*rankings) for name in names if name)
    units = list(dict.fromkeys(ranked))[:top]
    shown = buckets.filter(pl.col("name").is_in(units))

    # an empty point before each gap of over an hour (e.g. while the service was down),
    # so plots break the line there instead of drawing across it
    gap = pl.col("ts").diff().over("name", order_by="ts") > timedelta(hours=1)
    breaks = shown.filter(gap).select("name", pl.col("ts") - timedelta(minutes=every))
    shown = pl.concat([shown, breaks], how="diagonal").sort("name", "ts")

    rows = shown.with_columns(pl.col("ts").dt.epoch("ms")).to_dicts()
    return json.dumps({"units": units, "rows": rows})


class Handler(BaseHTTPRequestHandler):
    def do_GET(self) -> None:
        url = urlparse(self.path)

        if url.path == "/api/usage":
            query = {k: int(v[0]) for k, v in parse_qs(url.query).items()}
            body = usage(query["hours"], query["every"], query["top"]).encode()
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
