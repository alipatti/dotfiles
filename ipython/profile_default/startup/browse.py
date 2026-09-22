def browse(frame) -> None:
    """Open a native window showing a polars dataframe (see ~/.ipython/dfbrowse.py)."""
    import sys
    from pathlib import Path

    from IPython.core.getipython import get_ipython

    library = str(Path.home() / ".ipython")

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
