"""Personal Python helpers.

Submodules with extra dependencies are imported lazily on first attribute access,
so `import alipatti as ap` works without any extras and `ap.plot` only needs `[plot]`.
"""

import importlib
from types import ModuleType
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from . import cache as cache
    from . import plot as plot

SUBMODULES = {"cache", "plot"}


def __getattr__(name: str) -> ModuleType:
    if name in SUBMODULES:
        return importlib.import_module(f".{name}", __name__)

    raise AttributeError(f"module {__name__!r} has no attribute {name!r}")


def __dir__() -> list[str]:
    return [*globals(), *SUBMODULES]
