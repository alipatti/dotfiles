from typing import Any, Mapping
from IPython.core.magic import register_line_magic


@register_line_magic
def plconfig(line: str):
    """Set polars configuration options via pl.Config."""
    import polars as pl

    if line == "reset":
        pl.Config.restore_defaults()
        return

    kwargs = {
        k: int(v) if v.isdigit() else v
        for k, v in (kv.split("=") for kv in line.split())
    }

    print(kwargs)

    pl.Config(**kwargs)
