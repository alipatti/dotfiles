#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.12"
# dependencies = ["cyclopts"]
# ///
"""Send PDFs to Princeton's PawPrint queues, to be released at a copier with an ID card.

Wraps each PDF in a PJL header that sets duplex, then sends it straight to the print
server over LPD (RFC 1179), as the netid saved for eduroam. The DNS lookup and the
connection go over the campus network interface, so printing works with a Tailscale exit
node on. No printers need to be installed.
"""

import os
import re
import socket
import subprocess
import sys
from collections.abc import Iterator
from contextlib import contextmanager
from pathlib import Path
from typing import NamedTuple

from cyclopts import App
from cyclopts.types import ExistingFile

app = App(name="pawprint")

# from oit's linux setup: lpd://<netid>@ss226w.princeton.edu/PawPrint.
# https://csguide.cs.princeton.edu/printing/pawprint
SERVER = "ss226w.princeton.edu"
QUEUE = "PawPrint"
COLOR_QUEUE = "PawPrintColor"

EDUROAM_KEYCHAIN_SERVICE = "com.apple.network.eap.user.item.wlan.ssid.eduroam"
LPD_PORT = 515
LPD_SOURCE_PORTS = range(721, 732)  # rfc 1179 asks clients to send from these
LPD_TIMEOUT_SECONDS = 30
LPD_MAX_TITLE = 99
# pjl's universal exit language, which brackets the job
PJL_UEL = b"\x1b%-12345X"
IP_BOUND_IF = 25  # from <netinet/in.h>; python's socket module doesn't export it


class Interface(NamedTuple):
    name: str
    address: str
    dns: str


def run(*args: str) -> str:
    """A command's stdout, or "" if it fails."""
    result = subprocess.run(
        args,
        capture_output=True,
        text=True,
        check=False,
    )
    return "" if result.returncode else result.stdout.strip()


def eduroam_login() -> tuple[str, str]:
    """The netid and realm saved for eduroam, e.g. ("ab1234", "princeton.edu")."""
    keychain_item = run(
        "security",
        "find-generic-password",
        "-s",
        EDUROAM_KEYCHAIN_SERVICE,
    )

    if not (match := re.search(r'"acct"<blob>="([^@"]+)@([^"]+)"', keychain_item)):
        sys.exit("No saved eduroam login in the keychain. Connect to eduroam first.")

    return match[1], match[2]


def campus_interface(domain: str) -> Interface:
    """The physical interface whose DHCP lease is from `domain`'s network."""
    for _, name in socket.if_nameindex():
        if not name.startswith("en"):
            continue

        lease_domain = run(
            "ipconfig",
            "getoption",
            name,
            "domain_name",
        )

        if lease_domain == domain:
            return Interface(
                name,
                run("ipconfig", "getifaddr", name),
                run(
                    "ipconfig",
                    "getoption",
                    name,
                    "domain_name_server",
                ),
            )

    sys.exit(f"Not on the {domain} network. Connect to eduroam on campus.")


def resolve(host: str, interface: Interface) -> str:
    """Look up `host` with the campus DNS over the campus interface, not the exit node."""
    answer = run(
        "dig",
        "+short",
        "+time=2",
        "+tries=1",
        "-b",
        interface.address,
        f"@{interface.dns}",
        host,
        "A",
    )
    # +short also lists any cnames on the way to the address
    addresses = re.findall(r"^\d+\.\d+\.\d+\.\d+$", answer, re.MULTILINE)

    if not addresses:
        sys.exit(f"Can't resolve {host} via {interface.dns} on {interface.name}.")

    return addresses[-1]


def with_pjl(file: Path, double_sided: bool) -> bytes:
    """The PDF with a PJL header, which the copiers and PaperCut read duplex from."""
    pdf = file.read_bytes()

    if not pdf.startswith(b"%PDF"):
        sys.exit(f"{file} isn't a PDF.")

    header = "".join(
        [
            "@PJL\r\n",
            f"@PJL SET DUPLEX={'ON' if double_sided else 'OFF'}\r\n",
            "@PJL SET BINDING=LONGEDGE\r\n",
            "@PJL ENTER LANGUAGE=PDF\r\n",
        ]
    )
    return PJL_UEL + header.encode() + pdf + PJL_UEL


def bind_source_port(lpd: socket.socket) -> None:
    """Send from a port RFC 1179 allows, falling back to any port if they're taken."""
    for port in LPD_SOURCE_PORTS:
        try:
            lpd.bind(("", port))
            return
        except OSError:
            continue


@contextmanager
def lpd_connection(address: str, interface: str, queue: str) -> Iterator[socket.socket]:
    """A connection ready to receive one job for `queue`, bound to `interface`."""
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as lpd:
        lpd.setsockopt(socket.IPPROTO_IP, IP_BOUND_IF, socket.if_nametoindex(interface))
        bind_source_port(lpd)
        lpd.settimeout(LPD_TIMEOUT_SECONDS)
        lpd.connect((address, LPD_PORT))
        command(lpd, b"\x02" + queue.encode() + b"\n")
        yield lpd


def command(
    lpd: socket.socket,
    message: bytes,
    timeout: float | None = LPD_TIMEOUT_SECONDS,
) -> None:
    """Send a message and require the server's zero-byte acknowledgement."""
    lpd.settimeout(timeout)
    lpd.sendall(message)
    ack = lpd.recv(1)

    if not ack:
        sys.exit("Print server closed the connection.")

    if ack != b"\0":
        sys.exit(f"Print server refused {message[:40]!r} with {ack!r}.")


def send_file(
    lpd: socket.socket,
    code: bytes,
    name: str,
    data: bytes,
) -> None:
    command(lpd, code + f"{len(data)} {name}\n".encode())
    # large documents take longer than the usual timeout to upload
    command(lpd, data + b"\0", timeout=None)


def send_job(
    lpd: socket.socket,
    job: int,
    data: bytes,
    title: str,
    netid: str,
    copies: int,
) -> None:
    """Submit one job; returns once the server has acknowledged every byte."""
    host = socket.gethostname().split(".")[0][:31]
    data_name = f"dfA{job:03d}{host}"
    # a newline in the title would start a new control line
    title = " ".join(title.splitlines())[:LPD_MAX_TITLE]
    control = "".join(
        [
            f"H{host}\n",
            f"P{netid}\n",
            f"J{title}\n",
            f"N{title}\n",
            f"l{data_name}\n" * copies,
            f"U{data_name}\n",
        ]
    )

    send_file(
        lpd,
        b"\x02",
        f"cfA{job:03d}{host}",
        control.encode(),
    )
    send_file(
        lpd,
        b"\x03",
        data_name,
        data,
    )


@app.default
def pawprint(
    files: list[ExistingFile],
    /,
    *,
    color: bool = False,
    double_sided: bool = True,
    copies: int = 1,
):
    """Send PDFs to PawPrint.

    Parameters
    ----------
    files
        PDFs to print.
    color
        Use the color queue.
    double_sided
        Print on both sides of the page.
    copies
        Number of copies.
    """
    queue = COLOR_QUEUE if color else QUEUE
    netid, realm = eduroam_login()
    interface = campus_interface(realm)
    address = resolve(SERVER, interface)
    # wrap every file first, so a bad one doesn't leave the rest half sent
    jobs = [(file, with_pjl(file, double_sided)) for file in files]

    for i, (file, data) in enumerate(jobs):
        job = (os.getpid() + i) % 1000

        try:
            with lpd_connection(address, interface.name, queue) as lpd:
                send_job(
                    lpd,
                    job,
                    data,
                    file.name,
                    netid,
                    copies,
                )
        except OSError as error:
            sys.exit(f"Couldn't send {file} to {SERVER} ({address}): {error}.")

        print(f"Sent {file} to {queue} as {netid}.")


if __name__ == "__main__":
    app()
