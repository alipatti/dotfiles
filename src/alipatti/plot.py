"""Helpers for plotnine figures that match typst documents."""

from collections.abc import Iterator, Sequence
from contextlib import contextmanager
from copy import deepcopy
from pathlib import Path

import matplotlib as mpl
import matplotlib.pyplot as plt
import plotnine as pn
from plotnine.composition import Compose

type Figure = pn.ggplot | Compose

FONT = "NewComputerModern10"  # the 10pt cut of typst's default text font

PALETTE = [
    "#eb6834",
    "#2a78d6",
    "#1baf7a",
    "#eda100",
    "#e87ba4",
    "#008300",
]


def theme_ali(base_size: float = 11) -> pn.theme:
    """Return a classic theme set in FONT, with unboxed facet strips."""
    return pn.theme_classic(base_size=base_size, base_family=FONT) + pn.theme(
        strip_background=pn.element_blank(),
    )


@contextmanager
def math_font() -> Iterator[None]:
    """
    Render mathtext labels in Computer Modern math within the block.

    This matches typst, which sets math in New Computer Modern Math. Pointing
    mathtext at FONT instead would use the text font's italic Greek, whose α
    looks like an italic a. Matplotlib's settings are restored on exit, so
    nothing leaks into later figures.
    """
    with mpl.rc_context({"mathtext.fontset": "cm"}):
        yield


def center_panels(figure: Figure) -> Figure:
    """
    Set the right margin so the panels sit horizontally centered in the figure.

    The axis title and tick labels on the left push the panels right, so we draw
    the figure once, measure the gap between the figure edge and the leftmost
    panel, and use that as the right margin.
    """
    drawn = deepcopy(figure).draw()  # drawing mutates the figure, so measure a copy
    drawn.draw_without_rendering()  # run plotnine's layout engine
    left = min(axes.get_position().x0 for axes in drawn.axes)
    plt.close(drawn)

    margin = pn.theme(plot_margin_right=left)
    return figure & margin if isinstance(figure, Compose) else figure + margin


def save_figure(
    figure: Figure,
    name: str,
    directory: Path | str = "figures",
    extensions: Sequence[str] | str = "pdf",
    center: bool = True,
) -> list[Path]:
    """
    Save `figure` to `{directory}/{name}.{extension}` for each extension.

    Math is set in FONT for the duration of the save, and with `center` the
    panels are horizontally centered first. Returns the saved paths.
    """
    directory = Path(directory)
    directory.mkdir(parents=True, exist_ok=True)
    extensions = [extensions] if isinstance(extensions, str) else extensions
    paths = [directory / f"{name}.{extension}" for extension in extensions]

    # centering draws the figure, so it also needs the math font
    with math_font():
        figure = center_panels(figure) if center else figure
        for path in paths:
            figure.save(path, verbose=False)

    return paths
