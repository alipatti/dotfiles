#!/usr/bin/env python3
"""open a new window with the current cwd, splitting on the long axis.

kitty's tall/fat layouts fix the split direction, so pick tall (side by
side) when the tab is wide and fat (stacked) when it is narrow, leaving
the stack layout if the tab was zoomed. run via
`remote_control_script` so no remote control permission is needed.

with --layout-only, just pick the layout and launch nothing; nvim uses
this before showing its terminal windows.
"""

import json
import sys
import shutil
import subprocess

NARROW_WIDE_CUTOFF = 100

# kitty may run this with a minimal path, so fall back to the bundled binary
KITTEN = shutil.which("kitten") or "/Applications/kitty.app/Contents/MacOS/kitten"


def kitten(*args, capture=False):
    # kitty passes its control socket as an inherited fd (KITTY_LISTEN_ON=fd:N),
    # so the child must not close inherited fds
    return subprocess.run(
        [KITTEN, "@", *args],
        check=True,
        capture_output=capture,
        text=True,
        close_fds=False,
    ).stdout


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

    layout = "fat" if tab_columns(tab) < NARROW_WIDE_CUTOFF else "tall"
    # the bias comes from enabled_layouts in kitty.conf; goto-layout ignores
    # options that are not listed there
    kitten("goto-layout", layout)

    if "--layout-only" in sys.argv[1:]:
        return

    # pass the cwd explicitly: --cwd=current resolves against the script's own
    # cwd when invoked from remote control, not the focused window's
    focused = next(w for w in tab["windows"] if w["is_focused"])
    kitten("launch", "--type=window", f"--cwd={focused['cwd']}")


if __name__ == "__main__":
    main()
