#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.12"
# dependencies = ["cyclopts"]
# ///
"""Send files to Princeton's PawPrint queues, to be released at a copier with an ID card.

Converts each file to PostScript with cupsfilter and the queue's PPD, then sends it
straight to the print server over LPD (RFC 1179), as the netid saved for eduroam. The
DNS lookup and the connection go over the campus network interface, so printing works
with a Tailscale exit node on. Everything comes from the CUPS queues set up by OIT's
installer, the eduroam login in the keychain, and the campus network's DHCP options.
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
from urllib.parse import urlparse

from cyclopts import App

app = App(name="pawprint")

EDUROAM_KEYCHAIN_SERVICE = "com.apple.network.eap.user.item.wlan.ssid.eduroam"
LPD_PORT = 515
LPD_SOURCE_PORTS = range(721, 732)  # rfc 1179 asks clients to send from these
LPD_TIMEOUT_SECONDS = 30
LPD_MAX_TITLE = 99
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


def lpd_device(queue: str) -> tuple[str, str]:
    """The print server and remote queue name behind a local CUPS queue."""
    # matches any locale's wording of "device for <queue>: <uri>"
    pattern = rf"{re.escape(queue)}: (\S+://\S+)$"

    if not (match := re.search(pattern, run("lpstat", "-v"), re.MULTILINE)):
        sys.exit(f"No CUPS queue named {queue}. Run OIT's PawPrint installer.")

    uri = urlparse(match[1])

    if uri.scheme != "lpd" or not uri.hostname:
        sys.exit(f"{queue} isn't an LPD queue: {match[1]}.")

    return uri.hostname, uri.path.strip("/")


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


def to_postscript(file: Path, queue: str, double_sided: bool) -> bytes:
    """Render a file with the queue's PPD, including its duplex setup."""
    sides = "two-sided-long-edge" if double_sided else "one-sided"
    result = subprocess.run(
        [
            "cupsfilter",
            "-d",
            queue,
            "-m",
            "application/vnd.cups-postscript",
            "-o",
            f"sides={sides}",
            str(file),
        ],
        capture_output=True,
        check=False,
    )

    if result.returncode:
        sys.exit(f"Couldn't convert {file}:\n{result.stderr.decode()}")

    return result.stdout


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
    files: list[Path],
    /,
    *,
    color: bool = False,
    double_sided: bool = True,
    copies: int = 1,
):
    """Send files to PawPrint.

    Parameters
    ----------
    files
        Files to print.
    color
        Use the color queue.
    double_sided
        Print on both sides of the page.
    copies
        Number of copies.
    """
    queue = "PawPrintColor" if color else "PawPrint"
    netid, realm = eduroam_login()
    server, remote_queue = lpd_device(queue)
    interface = campus_interface(realm)
    address = resolve(server, interface)

    for i, file in enumerate(files):
        data = to_postscript(file, queue, double_sided)
        job = (os.getpid() + i) % 1000

        try:
            with lpd_connection(address, interface.name, remote_queue) as lpd:
                send_job(
                    lpd,
                    job,
                    data,
                    file.name,
                    netid,
                    copies,
                )
        except OSError as error:
            sys.exit(f"Couldn't send {file} to {server} ({address}): {error}.")

        print(f"Sent {file} to {remote_queue} as {netid}.")


if __name__ == "__main__":
    app()
