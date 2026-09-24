#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import subprocess
import sys
import time


def get_starship_rhs():
    result = subprocess.run(["starship", "prompt"], capture_output=True, text=True)
    lines = result.stdout.split("\n")
    line = lines[1] if len(lines) > 1 else (lines[0] if lines else "")

    # Remove everything up to first reset code (skips the directory part)
    line = re.sub(r".*?\x1b\[0m", "", line, count=1)
    # Remove alignment padding (spaces + color codes before actual RHS content)
    line = re.sub(r"^\s*\x1b\[[0-9;]*m\s+\x1b\[0m", "", line)
    # Keep only red/green ANSI codes and reset; strip everything else
    line = re.sub(r"\x1b\[(?!(?:0|3[12]|9[12])m)\d+(?:;\d+)*m", "", line)
    return line


def format_remaining(resets_at: int | None) -> str:
    """Format seconds until reset as a human-readable string."""
    if resets_at is None:
        return ""

    remaining = int(resets_at - time.time())
    if remaining <= 0:
        return "now"

    days, remainder = divmod(remaining, 86400)
    hours, remainder = divmod(remainder, 3600)
    minutes = remainder // 60

    if days > 0:
        return f"{days}d {hours}h"
    if hours > 0:
        return f"{hours}h {minutes:02d}m"
    return f"{minutes}m"


def main(context_cutoff: int = 75, five_hour_cutoff: int = 50, week_cutoff: int = 80) -> None:
    data_from_claude = json.load(sys.stdin)

    model = (data_from_claude.get("model") or {}).get("display_name", "")
    rate_limits = data_from_claude.get("rate_limits") or {}

    five_h_data = rate_limits.get("five_hour") or {}
    week_data = rate_limits.get("seven_day") or {}

    five_h = five_h_data.get("used_percentage")
    five_h_resets_at = five_h_data.get("resets_at")
    week = week_data.get("used_percentage")
    week_resets_at = week_data.get("resets_at")
    context = (data_from_claude.get("context_window") or {}).get("used_percentage")

    model_icon = "\U000f06a9"  # 󰚩
    usage = f"{model_icon} {model}"

    if context is not None and round(context) > context_cutoff:
        usage = usage + f" | {round(context)}% (context)"

    limits = []
    if five_h is not None and round(five_h) > five_hour_cutoff:
        remaining = format_remaining(five_h_resets_at)
        label = remaining if remaining else "5h"
        limits.append(f"{round(five_h)}% ({label})")
    if week is not None and round(week) > week_cutoff:
        remaining = format_remaining(week_resets_at)
        label = remaining if remaining else "7d"
        limits.append(f"{round(week)}% ({label})")
    if limits:
        usage = usage + " | " + " ".join(limits)

    starship = get_starship_rhs()
    if starship:
        print(f"{usage} | {starship}")
    else:
        print(usage)


if __name__ == "__main__":
    main()
