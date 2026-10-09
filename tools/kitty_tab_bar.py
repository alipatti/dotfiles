"""draw each tab as a rounded pill, loaded by kitty's `tab_bar_style custom`.

the title comes from fish_title (`[host] path | command`). kitty truncates
titles by overwriting the last cell, which drops the pill's right cap, so
truncate here instead. cutting from the end shortens the command first, then
the path. docs: https://sw.kovidgoyal.net/kitty/conf/#opt-kitty.tab_bar_style
"""

import os

from kitty.fast_data_types import Screen, get_boss, wcswidth
from kitty.tab_bar import DrawData, ExtraData, TabBarData

LEFT_CAP = ""
RIGHT_CAP = ""

# caps plus the padding inside them, and the gap after the pill
CHROME_WIDTH = 4
GAP = " "

# palette colors, so they follow the theme. yellow matches starship's
# ssh hostname
BLUE = (4 << 8) | 1
YELLOW = (3 << 8) | 1
SURFACE = (8 << 8) | 1
DEFAULT = 0


def is_remote(tab: TabBarData) -> bool:
    """Whether the tab is on another host, per fish_title or the running exe."""
    if tab.title.startswith("["):
        return True

    kitty_tab = get_boss().tab_for_id(tab.tab_id)
    exe = kitty_tab and kitty_tab.get_exe_of_active_window()
    return os.path.basename(exe or "") == "ssh"


def truncate(text: str, width: int) -> str:
    if wcswidth(text) <= width:
        return text

    while text and wcswidth(text) > width - 1:
        text = text[:-1]

    return text.rstrip() + "…"


def draw_tab(
    draw_data: DrawData,
    screen: Screen,
    tab: TabBarData,
    before: int,
    max_tab_length: int,
    index: int,
    is_last: bool,
    extra_data: ExtraData,
) -> int:
    remote = is_remote(tab)
    fill = (YELLOW if remote else BLUE) if tab.is_active else SURFACE
    text = screen.cursor.fg if tab.is_active else (YELLOW if remote else DEFAULT)
    title = truncate(tab.title, max(1, max_tab_length - CHROME_WIDTH - len(GAP)))

    screen.cursor.fg, screen.cursor.bg = fill, DEFAULT
    screen.draw(LEFT_CAP)
    screen.cursor.fg, screen.cursor.bg = text, fill
    screen.draw(f" {title} ")
    screen.cursor.fg, screen.cursor.bg = fill, DEFAULT
    screen.draw(RIGHT_CAP)

    end = screen.cursor.x
    if end < screen.columns:
        screen.draw(GAP)

    return end
