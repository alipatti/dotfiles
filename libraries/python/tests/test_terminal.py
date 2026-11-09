import base64
import io
from collections.abc import Iterator
from typing import Final

import pytest

from alipatti.terminal import (
    TerminalColors,
    _as_terminal_colors,
    _collect_color_replies,
    _kitty_escapes,
    _parse_color_replies,
    shows_kitty_graphics,
)


def osc_reply(query: str, rgb: str, end: str = "\x1b\\") -> bytes:
    return f"\x1b]{query};rgb:{rgb}{end}".encode()


#: a dark terminal's full answer: blue and yellow set, the other ANSI colours grey
DARK_REPLIES: Final = b"".join(
    osc_reply(query, rgb)
    for query, rgb in [
        ("10", "c0c0/caca/f5f5"),
        ("11", "1a1a/1b1b/2626"),
        *((f"4;{n}", "4040/4040/4040") for n in range(16) if n not in (3, 4)),
        ("4;3", "e0e0/afaf/6868"),
        ("4;4", "7a7a/a2a2/f7f7"),
    ]
)


def chunked_reader(chunks: list[bytes]) -> Iterator[bytes]:
    yield from chunks
    while True:
        yield b""  # timed out


def test_parse_color_replies_run_together() -> None:
    """Parse replies sent back to back, ended by ST or BEL, with 2 or 4 hex digits."""
    replies = (
        osc_reply("10", "ffff/0000/8080")
        + osc_reply("11", "00/ff/80", end="\x07")
        + osc_reply("4;12", "1a1a/2b2b/3c3c")
    )

    assert _parse_color_replies(replies) == {
        "10": "#ff0080",
        "11": "#00ff80",
        "4;12": "#1a2b3c",
    }


def test_parse_color_replies_skips_partial_ones() -> None:
    """Leave out a reply cut off before its last component."""
    replies = osc_reply("10", "ffff/ffff/ffff") + b"\x1b]11;rgb:0000/00"

    assert _parse_color_replies(replies) == {"10": "#ffffff"}


def test_collect_color_replies_across_reads() -> None:
    """Join replies split across reads, stopping once every query is answered."""
    chunks = [DARK_REPLIES[:7], DARK_REPLIES[7:100], DARK_REPLIES[100:]]
    reads = chunked_reader(chunks)

    colors = _collect_color_replies(lambda _: next(reads), timeout=1)

    assert len(colors) == 18
    assert colors["4;4"] == "#7aa2f7"


def test_collect_color_replies_without_an_answer() -> None:
    """Return nothing when the terminal never answers."""
    reads = chunked_reader([])

    assert _collect_color_replies(lambda _: next(reads), timeout=1) == {}


def test_as_terminal_colors_names_the_replies() -> None:
    """Map the foreground, background and ANSI replies to their fields."""
    colors = _as_terminal_colors(_parse_color_replies(DARK_REPLIES))

    assert colors == TerminalColors(
        foreground="#c0caf5",
        background="#1a1b26",
        ansi=(
            *("#404040",) * 3,
            "#e0af68",
            "#7aa2f7",
            *("#404040",) * 11,
        ),
    )


def test_as_terminal_colors_needs_every_colour() -> None:
    """Return None when the terminal leaves out a colour."""
    colors = _parse_color_replies(DARK_REPLIES)
    del colors["4;3"]

    assert _as_terminal_colors(colors) is None


def test_kitty_escapes_chunk_the_base64() -> None:
    """Split the base64 into chunks; the first carries the format, all but the last
    say more follows."""
    png = bytes(range(256)) * 20  # 5120 bytes: 6828 of base64, two chunks
    data = base64.standard_b64encode(png).decode()

    escapes = _kitty_escapes(png, columns=80, chunk_size=4096)

    assert escapes == (
        f"\x1b_Gf=100,a=T,c=80,m=1;{data[:4096]}\x1b\\\x1b_Gm=0;{data[4096:]}\x1b\\"
    )


def test_kitty_escapes_fit_one_chunk() -> None:
    """Send a small image in a single escape with `m=0`."""
    assert _kitty_escapes(b"png") == "\x1b_Gf=100,a=T,m=0;cG5n\x1b\\"


class FakeStream(io.StringIO):
    def __init__(self, tty: bool) -> None:
        super().__init__()
        self.tty = tty

    def isatty(self) -> bool:
        return self.tty


@pytest.mark.parametrize(
    ("tty", "env", "kitty"),
    [
        (True, {"TERM": "xterm-kitty"}, True),
        (True, {"TERM": "xterm-256color", "KITTY_WINDOW_ID": "1"}, True),
        (True, {"TERM": "xterm-256color"}, False),
        (False, {"TERM": "xterm-kitty", "KITTY_WINDOW_ID": "1"}, False),
    ],
)
def test_shows_kitty_graphics(
    monkeypatch: pytest.MonkeyPatch,
    tty: bool,
    env: dict[str, str],
    kitty: bool,
) -> None:
    """Detect kitty from `TERM` or `KITTY_WINDOW_ID`, only on a terminal."""
    monkeypatch.delenv("KITTY_WINDOW_ID", raising=False)
    for name, value in env.items():
        monkeypatch.setenv(name, value)

    assert shows_kitty_graphics(FakeStream(tty)) == kitty
