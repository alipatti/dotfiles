"""Ask the terminal about itself and show images in it with kitty's graphics protocol.

Uses only the standard library. Unix only.
"""

import base64
import fcntl
import os
import re
import select
import struct
import sys
import termios
import time
import tty
from collections.abc import Callable
from dataclasses import dataclass
from functools import cache, partial
from typing import Final, TextIO

#: the foreground (OSC 10), the background (OSC 11), and the 16 ANSI colours (OSC 4),
#: keyed as their replies are by `_parse_color_replies`
_COLOR_QUERIES: Final = ("10", "11", *(f"4;{n}" for n in range(16)))

_COLOR_REPLY: Final = re.compile(
    rb"\x1b\]((?:10|11|4;\d+));rgb:([0-9a-f]{1,4})/([0-9a-f]{1,4})/([0-9a-f]{1,4})",
    re.IGNORECASE,
)


@dataclass(frozen=True)
class TerminalColors:
    """The terminal's colours, as hex."""

    foreground: str
    background: str
    #: the 16 ANSI colours, by index: black, red, green, yellow, blue, magenta, cyan,
    #: white, then their bright versions
    ansi: tuple[str, ...]


@cache
def terminal_colors() -> TerminalColors | None:
    """The terminal's colours, asked for once per process; None if there's no
    terminal or it doesn't say them all."""
    return _as_terminal_colors(_query_terminal_colors())


def shows_kitty_graphics(stream: TextIO | None = None) -> bool:
    """Whether `stream` (stdout by default) is a terminal that looks like kitty, so
    takes kitty's graphics protocol: `TERM` contains kitty, or `KITTY_WINDOW_ID` is
    set."""
    stream = stream or sys.stdout
    return stream.isatty() and (
        "kitty" in os.environ.get("TERM", "") or "KITTY_WINDOW_ID" in os.environ
    )


def _query_terminal_colors(timeout: float = 0.3) -> dict[str, str]:
    """Ask the controlling terminal for its colours (see `_COLOR_QUERIES`); empty
    without one."""
    queries = "".join(f"\x1b]{query};?\x07" for query in _COLOR_QUERIES)
    try:
        fd = os.open("/dev/tty", os.O_RDWR | os.O_NOCTTY)
    except OSError:
        return {}

    try:
        settings = termios.tcgetattr(fd)
        tty.setraw(fd)
        try:
            os.write(fd, queries.encode())
            return _collect_color_replies(partial(_read_ready, fd), timeout)
        finally:
            # flushing drops replies that came too late, so they don't reach the shell
            termios.tcsetattr(fd, termios.TCSAFLUSH, settings)
    except termios.error:
        return {}
    finally:
        os.close(fd)


def _read_ready(fd: int, timeout: float) -> bytes:
    ready, _, _ = select.select([fd], [], [], timeout)
    return os.read(fd, 1024) if ready else b""


def _collect_color_replies(
    read: Callable[[float], bytes],
    timeout: float,
) -> dict[str, str]:
    """Colours from what `read` (given the time left, returning nothing once it's
    up) gives until every query is answered or `timeout` seconds pass."""
    deadline = time.monotonic() + timeout
    replies = b""
    colors: dict[str, str] = {}
    while len(colors) < len(_COLOR_QUERIES):
        remaining = deadline - time.monotonic()
        chunk = read(remaining) if remaining > 0 else b""
        if not chunk:
            break

        replies += chunk
        colors = _parse_color_replies(replies)

    return colors


def _parse_color_replies(replies: bytes) -> dict[str, str]:
    """Hex colours from OSC 10, 11 and 4 replies (`10`, `11`, `4;N` keys); incomplete
    replies are left out."""
    return {
        match[1].decode(): "#" + "".join(map(_hex_component, match.groups()[1:]))
        for match in _COLOR_REPLY.finditer(replies)
    }


def _hex_component(digits: bytes) -> str:
    """An `rgb:` component of 1-4 hex digits as two."""
    value = int(digits, 16) / (16 ** len(digits) - 1)
    return f"{round(value * 255):02x}"


def _as_terminal_colors(colors: dict[str, str]) -> TerminalColors | None:
    """`colors` (keyed as by `_parse_color_replies`) if none are missing."""
    if not all(query in colors for query in _COLOR_QUERIES):
        return None

    return TerminalColors(
        foreground=colors["10"],
        background=colors["11"],
        ansi=tuple(colors[f"4;{n}"] for n in range(16)),
    )


def _cell_pixels(stream: TextIO) -> tuple[float, float] | None:
    """A terminal cell's width and height in pixels, from the window size the
    terminal reports (`TIOCGWINSZ`; ssh forwards it); None if it doesn't say."""
    try:
        size = fcntl.ioctl(stream.fileno(), termios.TIOCGWINSZ, bytes(8))
    except OSError:
        return None

    rows, columns, width, height = struct.unpack("HHHH", size)
    if not (rows and columns and width and height):
        return None

    return width / columns, height / rows


def _kitty_escapes(
    png: bytes,
    columns: int | None = None,
    chunk_size: int = 4096,
) -> str:
    """Escapes that show `png` with kitty's graphics protocol, sent inline (direct
    transmission, so it works over ssh) in chunks of `chunk_size` bytes of base64, scaled to
    `columns` terminal columns if given. Only the first carries the format, action and
    size; every one but the last has `m=1`."""
    size = f"c={columns}," if columns else ""
    data = base64.standard_b64encode(png).decode()
    chunks = [data[i : i + chunk_size] for i in range(0, len(data), chunk_size)]

    return "".join(
        f"\x1b_G{f'f=100,a=T,{size}' if i == 0 else ''}m={int(i < len(chunks) - 1)};"
        f"{chunk}\x1b\\"
        for i, chunk in enumerate(chunks)
    )
