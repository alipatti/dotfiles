from pathlib import Path

from IPython.core.getipython import get_ipython
from IPython.core.magic import register_line_magic


def tools_dir() -> Path:
    """The dotfiles tools directory, found relative to this startup file.

    ipython execs startup files without setting __file__, so the location comes
    from the profile's startup directory. resolving follows the home-manager
    symlinks back into the repo checkout, wherever it happens to live.
    """
    startup = Path(get_ipython().profile_dir.startup_dir).resolve()
    return startup.parents[1] / "tools"


def browse(frame) -> None:
    """Open a native window showing a polars dataframe (see tools/dfbrowse.py)."""
    import sys

    library = str(tools_dir())
    if library not in sys.path:
        sys.path.append(library)

    # imported here so sessions that never browse don't need pyobjc
    import dfbrowse

    shell = get_ipython()
    # title the window with the first variable bound to this very frame.
    # underscore names are skipped since ipython's output history lives there
    names = (
        name
        for name, value in shell.user_ns.items()
        if value is frame and not name.startswith("_")
    )

    # pump the cocoa event loop while the prompt waits for input. a loop that is
    # already running (say %gui qt) drives cocoa windows too, so it is left alone
    if shell.active_eventloop is None:
        shell.enable_gui("osx")

    dfbrowse.browse(frame, next(names, dfbrowse.DEFAULT_TITLE))


@register_line_magic("browse")
def browse_magic(line: str) -> None:
    """%browse: open the last result in the browser."""
    import polars as pl

    last = get_ipython().user_ns.get("_")

    if isinstance(last, (pl.DataFrame, pl.Series)):
        browse(last)
    else:
        print(f"the last result is a {type(last).__name__}, not a polars frame")
