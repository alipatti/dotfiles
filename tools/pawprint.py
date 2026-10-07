#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.12"
# dependencies = ["cyclopts"]
# ///
"""Send files to Princeton's PawPrint queues, to be released at a copier with an ID card.

Uses the PawPrint and PawPrintColor CUPS queues set up by OIT's installer.
"""

import subprocess
from pathlib import Path

from cyclopts import App

app = App(name="pawprint")


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
    sides = "two-sided-long-edge" if double_sided else "one-sided"

    subprocess.run(
        [
            "lpr",
            "-P",
            queue,
            "-o",
            f"sides={sides}",
            "-#",
            str(copies),
            *map(str, files),
        ],
        check=True,
    )


if __name__ == "__main__":
    app()
