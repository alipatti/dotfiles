#!/usr/bin/env python3
"""Status line for claude code: model, usage, and the right side of the starship prompt."""

from __future__ import annotations

import json
import re
import subprocess
import sys
import time

# the modules on the right side of the starship prompt (see home/modules/prompt.nix)
STARSHIP_MODULES = [
    "rust",
    "python",
    "git_branch",
    "git_commit",
    "git_state",
    "git_status",
    "git_metrics",
]

MODEL_ICON = "\U000f06a9"  # 󰚩
WEEK_CUTOFF = 80

# usage at or above these percentages is colored yellow and red
YELLOW_CUTOFF = 75
RED_CUTOFF = 90

ANSI = r"\x1b\[[0-9;]*m"
# everything except reset, red, and green
UNWANTED_ANSI = re.compile(r"\x1b\[(?!(?:0|3[12]|9[12])m)[0-9;]*m")


def visible_strip(text: str) -> str:
    """Strip whitespace from the ends of the text, looking through ansi codes."""
    text = re.sub(rf"^((?:{ANSI})*)\s+", r"\1", text)
    return re.sub(rf"\s+((?:{ANSI})*)$", r"\1", text)


def starship_module(name: str, path: str) -> str:
    result = subprocess.run(
        ["starship", "module", name, "--path", path, "--logical-path", path],
        capture_output=True,
        text=True,
        check=False,
    )
    return visible_strip(UNWANTED_ANSI.sub("", result.stdout))


def starship_rhs(path: str) -> str:
    modules = (starship_module(name, path) for name in STARSHIP_MODULES)
    return " ".join(m for m in modules if re.sub(ANSI, "", m).strip())


def time_until(timestamp: int) -> str:
    remaining = int(timestamp - time.time())
    if remaining <= 0:
        return "now"

    days, remainder = divmod(remaining, 86400)
    hours, remainder = divmod(remainder, 3600)
    minutes = remainder // 60

    if days:
        return f"{days}d {hours}h"

    if hours:
        return f"{hours}h {minutes:02d}m"

    return f"{minutes}m"


def format_usage(label: str, percent: float, note: str | None = None) -> str:
    percent = round(percent)
    text = f"{label}: {percent}%" + (f" ({note})" if note else "")

    if percent >= RED_CUTOFF:
        return f"\x1b[31m{text}\x1b[0m"

    if percent >= YELLOW_CUTOFF:
        return f"\x1b[33m{text}\x1b[0m"

    return text


def format_limit(label: str, limit: dict) -> str:
    resets_at = limit.get("resets_at")
    remaining = time_until(resets_at) if resets_at is not None else None
    return format_usage(label, limit["used_percentage"], remaining)


def main() -> None:
    data = json.load(sys.stdin)

    model = (data.get("model") or {}).get("display_name", "")
    context = (data.get("context_window") or {}).get("used_percentage")
    rate_limits = data.get("rate_limits") or {}
    five_hour = rate_limits.get("five_hour") or {}
    week = rate_limits.get("seven_day") or {}
    cwd = (data.get("workspace") or {}).get("current_dir") or data.get("cwd") or "."

    usage = []
    if context is not None:
        usage.append(format_usage("context", context))

    if five_hour.get("used_percentage") is not None:
        usage.append(format_limit("usage", five_hour))

    if round(week.get("used_percentage") or 0) > WEEK_CUTOFF:
        usage.append(format_limit("week", week))

    sections = [
        f"{MODEL_ICON} {model}",
        starship_module("directory", cwd),
        starship_rhs(cwd),
    ]
    print(" | ".join(filter(None, sections)))
    if usage:
        print(" | ".join(usage))


if __name__ == "__main__":
    main()
