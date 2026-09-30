"""kitty watcher that lets nvim open and drive sibling windows, even over ssh.

nvim can't reach kitty's control socket from a remote host, but it can write
to its own terminal. so it sets a user variable (OSC 1337 SetUserVar) holding
a json message, and this watcher, loaded for every window via `watcher` in
kitty.conf, acts on it. anything printed to a terminal can set user vars, so
messages carry a secret that only this machine's shells (and, through
`kitten ssh`, their remote sessions) know. see nvim/lua/kitty_bridge.lua.

windows opened for a remote nvim run on the same host, over nvim's ssh
connection. their commands go through the remote login shell, which
`login_shell` in kitty's ssh.conf can point at one with the full environment
(see kitty.nix).
"""

import hmac
import json
import os
import shlex
import sys
import time
from pathlib import Path
from typing import Any

from kittens.ssh.utils import (
    set_cwd_in_cmdline,
    set_env_in_cmdline,
    set_server_args_in_cmdline,
)
from kitty.boss import Boss
from kitty.constants import kitten_exe
from kitty.fast_data_types import add_timer
from kitty.window import Window

sys.path.insert(0, os.path.dirname(__file__))
from kitty_split import NARROW_WIDE_CUTOFF, tab_columns

USER_VAR = "kitty_bridge"
SECRET_FILE = Path.home() / ".local/state/kitty-bridge-secret"

# user vars that tag the windows nvim opens, so they can be found again
ROLE_VAR = "nvim_role"
PARENT_VAR = "nvim_parent"

POLL_SECONDS = 0.1
# paste anyway if a program hasn't asked for input after this long
STARTUP_TIMEOUT_SECONDS = 30
# fish drops input that arrives right after its first prompt
STARTUP_SETTLE_SECONDS = 0.3


def on_set_user_var(
    boss: Boss,
    window: Window,
    data: dict[str, Any],
) -> None:
    if data["key"] != USER_VAR or not data["value"]:
        return

    # keep the secret out of `kitten @ ls`
    window.user_vars.pop(USER_VAR, None)
    message = json.loads(data["value"])
    if not hmac.compare_digest(
        message.pop("secret", ""), SECRET_FILE.read_text().strip()
    ):
        return

    parent = f"{window.id}-{message['pid']}"
    match message["op"]:
        case "open":
            open_window(boss, window, parent, message)
        case "close":
            for w in windows_of(boss, parent):
                boss.mark_window_for_close(w)
        case "focus":
            rc(boss, window, "focus-window", f"--match=id:{message['window']}")


def open_window(
    boss: Boss,
    window: Window,
    parent: str,
    message: dict[str, Any],
) -> None:
    """focus or send text to the window for a role, launching it if needed."""
    show(boss, window)
    role, text = message["role"], message.get("text")

    existing = next(
        (w for w in windows_of(boss, parent) if w.user_vars.get(ROLE_VAR) == role), None
    )
    if existing:
        if text is None:
            rc(boss, window, "focus-window", f"--match=id:{existing.id}")
        else:
            paste(existing, text, message.get("submit", False))
        return

    args = [
        "launch",
        # nvim's tab, which needn't be the active one
        f"--match=id:{window.tabref().id}",
        "--type=window",
        "--location=last",
        f"--var={ROLE_VAR}={role}",
        f"--var={PARENT_VAR}={parent}",
    ]
    if text is not None:
        args.append("--keep-focus")

    cmd = message.get("cmd") or []
    if remote := window.ssh_kitten_cmdline():
        # the same `kitten ssh` as nvim's window, in nvim's directory
        argv = [kitten_exe(), *remote[1:]] if remote[0] == "kitten" else list(remote)
        set_cwd_in_cmdline(message["cwd"], argv)
        set_env_in_cmdline(message["env"], argv, clone=False)
        # the remote shell gets one string, joined unquoted
        set_server_args_in_cmdline(
            [shlex.join(cmd)] if cmd else [], argv, allocate_tty=bool(cmd)
        )
        args += argv
    else:
        args += [f"--cwd={message['cwd']}"]
        args += [f"--env={k}={v}" for k, v in message["env"].items()]
        args += cmd

    new = boss.window_id_map[int(rc(boss, window, *args))]
    if text is not None:
        paste_when_ready(new, text, message.get("submit", False))


def paste_when_ready(
    window: Window,
    text: str,
    submit: bool,
) -> None:
    """paste once the program reads input, which it signals by turning on
    bracketed paste. a little later, since fish drops input that arrives
    right after its first prompt"""
    deadline = time.monotonic() + STARTUP_TIMEOUT_SECONDS
    ready_at = None

    def poll(timer_id: int | None) -> None:
        nonlocal ready_at
        if window.destroyed:
            return
        now = time.monotonic()
        if ready_at is None and (
            window.screen.in_bracketed_paste_mode or now > deadline
        ):
            ready_at = now + STARTUP_SETTLE_SECONDS
        if ready_at is not None and now > ready_at:
            paste(window, text, submit)
        else:
            add_timer(poll, POLL_SECONDS, False)

    poll(None)


def paste(
    window: Window,
    text: str,
    submit: bool,
) -> None:
    # bracketed if the program asked for it, which keeps multiline text in
    # one piece; the enter that runs it has to come after
    window.paste_text(text)
    if submit:
        window.write_to_child("\r")


def show(
    boss: Boss,
    window: Window,
) -> None:
    """unzoom and pick tall or fat by width, like `kitty_split.py --layout-only`."""
    tabs = (
        t for os_window in json.loads(rc(boss, window, "ls")) for t in os_window["tabs"]
    )
    tab = next(t for t in tabs if any(w["id"] == window.id for w in t["windows"]))
    window.tabref().goto_layout(
        "fat" if tab_columns(tab) < NARROW_WIDE_CUTOFF else "tall"
    )


def windows_of(
    boss: Boss,
    parent: str,
) -> list[Window]:
    return [
        w for w in boss.window_id_map.values() if w.user_vars.get(PARENT_VAR) == parent
    ]


def rc(
    boss: Boss,
    window: Window,
    *args: str,
) -> Any:
    return boss.call_remote_control(window, args)
