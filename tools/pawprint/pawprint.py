#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.12"
# dependencies = ["cyclopts"]
# ///
"""Send files to Princeton's PawPrint queues, to be released at a copier with an ID card.

Uses the PawPrint and PawPrintColor CUPS queues set up by OIT's installer.
"""

import re
import subprocess
import sys
import time
from pathlib import Path

from cyclopts import App

app = App(name="pawprint")

POLL_SECONDS = 1
FAILED_STATES = {"canceled", "aborted"}


def job_attributes(job_id: str) -> dict[str, str]:
    """The local cups job's attributes, as printed by ipptool."""
    output = subprocess.run(
        ["ipptool", "-tv", f"ipp://localhost/jobs/{job_id}", "get-job-attributes.test"],
        capture_output=True,
        text=True,
        check=False,
    ).stdout
    return dict(re.findall(r"^\s*(job-[\w-]+) \(\w+\) = (.*)$", output, re.MULTILINE))


def wait_for(job_id: str) -> None:
    """Block until cups has handed the job to the print server, echoing status changes."""
    message = ""
    while True:
        attributes = job_attributes(job_id)
        state = attributes.get("job-state")

        if attributes.get("job-printer-state-message", "") != message:
            message = attributes["job-printer-state-message"]
            message and print(message, file=sys.stderr)

        if state == "completed":
            return

        if state in FAILED_STATES:
            sys.exit(f"job {job_id} {state}: {attributes.get('job-state-reasons')}")

        time.sleep(POLL_SECONDS)


@app.default
def pawprint(
    files: list[Path],
    /,
    *,
    color: bool = False,
    double_sided: bool = True,
    copies: int = 1,
    wait: bool = False,
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
    wait
        Wait until the print server has received the job.
    """
    queue = "PawPrintColor" if color else "PawPrint"
    sides = "two-sided-long-edge" if double_sided else "one-sided"

    result = subprocess.run(
        [
            "lp",
            "-d",
            queue,
            "-o",
            f"sides={sides}",
            "-n",
            str(copies),
            *map(str, files),
        ],
        stdout=subprocess.PIPE,
        text=True,
        check=False,
    )
    print(result.stdout, end="")

    # lp has already printed why it failed
    if result.returncode:
        sys.exit(result.returncode)

    if wait:
        # lp prints "request id is PawPrint-42 (1 file(s))"
        job_id = re.search(r"request id is \S+-(\d+)", result.stdout)[1]
        wait_for(job_id)
        print(f"{queue}-{job_id} received")


if __name__ == "__main__":
    app()
