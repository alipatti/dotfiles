#!/usr/bin/env python3
"""open a new window with the current cwd, splitting on the long axis.

kitty's tall/fat layouts fix the split direction, so pick tall (side by
side) when the tab is wide and fat (stacked) when it is narrow, leaving
the stack layout if the tab was zoomed. run via
`remote_control_script` so no remote control permission is needed.

with --layout-only, just pick the layout and launch nothing; nvim uses
this before showing its terminal windows.

kitty also loads this file as a watcher (see kitty.nix), so on_resize
reflows tall/fat when the window is resized.
"""

import json
import shutil
import subprocess
import sys

NARROW_WIDE_CUTOFF = 100

KITTEN = shutil.which("kitten")


def kitten(*args, capture=False):
    assert KITTEN, "`kitten` not on path"

    # kitty passes its control socket as an inherited fd (KITTY_LISTEN_ON=fd:N),
    # so the child must not close inherited fds
    return subprocess.run(
        [KITTEN, "@", *args],
        check=True,
        capture_output=capture,
        text=True,
        close_fds=False,
    ).stdout


def layout_for(columns):
    return "fat" if columns < NARROW_WIDE_CUTOFF else "tall"


def on_resize(boss, window, data):
    tab = window.tabref()

    # leave zoomed (stack) tabs alone
    if tab is None or tab.current_layout.name not in ("tall", "fat"):
        return

    from kitty.fast_data_types import viewport_for_window

    central, *_, cell_width, _ = viewport_for_window(tab.os_window_id)
    layout = layout_for(central.width // cell_width)

    # goto_layout resizes the windows again, so only switch on a change
    if layout != tab.current_layout.name:
        tab.goto_layout(layout)


def tab_columns(tab):
    """total width of the tab in cells, reconstructed from its windows."""
    cols = [w["columns"] for w in tab["windows"]]
    if tab["layout"] == "tall" and len(cols) > 1:
        # main window on the left, the rest tiled on the right
        main = tab["layout_opts"].get("full_size", 1)
        return sum(cols[:main]) + max(cols[main:], default=0)
    # fat, stack, or a single window: every window spans the full width
    return max(cols)


def active_tab():
    for os_window in json.loads(kitten("ls", capture=True)):
        if not os_window["is_active"]:
            continue
        for tab in os_window["tabs"]:
            if tab["is_active"]:
                return tab
    raise SystemExit("no active tab")


def main():
    tab = active_tab()

    layout = layout_for(tab_columns(tab))
    # the bias comes from enabled_layouts in kitty.conf; goto-layout ignores
    # options that are not listed there
    kitten("goto-layout", layout)

    if "--layout-only" in sys.argv[1:]:
        return

    # --cwd=current resolves against the source window, which defaults to the
    # script's own when invoked from remote control. when the focused window
    # is running `kitten ssh`, this also opens the new window on the remote
    focused = next(w for w in tab["windows"] if w["is_focused"])
    kitten(
        "launch",
        "--type=window",
        "--cwd=current",
        f"--source-window=id:{focused['id']}",
    )


if __name__ == "__main__":
    main()
