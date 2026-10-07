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

app = App()


@app.default
def pawprint(
    files: list[Path],
    /,
    *,
    color: bool = False,
    single_sided: bool = False,
    copies: int = 1,
):
    """Print FILES in black and white, double-sided, unless told otherwise.

    Parameters
    ----------
    files
        Files to print.
    color
        Use the color queue.
    single_sided
        Print on one side of the page.
    copies
        Number of copies.
    """
    queue = "PawPrintColor" if color else "PawPrint"
    sides = "one-sided" if single_sided else "two-sided-long-edge"

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
