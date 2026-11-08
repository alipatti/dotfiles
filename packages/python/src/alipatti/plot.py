"""Helpers for plotnine figures.

Each `Target` is a place figures go: `"typst"` figures are saved with `save_figure`,
and `"terminal"` ones are drawn in kitty with `show_terminal`, in the terminal's
colours.
"""

import shutil
import sys
from collections.abc import Generator, Iterator, Sequence
from contextlib import contextmanager
from copy import deepcopy
from io import BytesIO
from pathlib import Path
from typing import Final, Literal, TextIO

import matplotlib as mpl
import matplotlib.pyplot as plt
import plotnine as pn
from matplotlib.figure import Figure as MplFigure
from plotnine.composition import Compose

from alipatti.terminal import _cell_pixels, _kitty_escapes, terminal_colors

type Figure = pn.ggplot | Compose
type Target = Literal["typst", "terminal"]

FONT = "NewComputerModern10"  # the 10pt cut of typst's default text font

PALETTE = [
    "#eb6834",
    "#2a78d6",
    "#1baf7a",
    "#eda100",
    "#e87ba4",
    "#008300",
]


#: the ANSI colours (by index) closest in hue to `PALETTE`'s
_ANSI_PALETTE: Final = (
    1,  # red
    4,  # blue
    6,  # cyan
    3,  # yellow
    5,  # magenta
    2,  # green
)

_POINTS_PER_INCH: Final = 72


def theme_ali(
    base_size: float = 11,
    target: Target = "typst",
) -> pn.theme:
    """
    Return a classic theme with unboxed facet strips, styled for `target`.

    For `"typst"` text is set in FONT. For `"terminal"` it's in matplotlib's
    default font, with the terminal's foreground on its background (opaque: text
    smoothed against a transparent background leaves ragged edges once kitty
    composites it), or dark on a transparent background if the terminal doesn't
    say its colours.
    """
    family = FONT if target == "typst" else None
    theme = pn.theme_classic(
        base_size=base_size,
        base_family=family,
    ) + pn.theme(
        strip_background=pn.element_blank(),
    )

    if target == "typst":
        return theme

    colors = terminal_colors()
    foreground = colors.foreground if colors else None
    fill = colors.background if colors else "none"

    return theme + pn.theme(
        text=pn.element_text(color=foreground),
        axis_text=pn.element_text(color=foreground),
        strip_text=pn.element_text(color=foreground),
        axis_line=pn.element_line(color=foreground),
        axis_ticks=pn.element_line(color=foreground),
        panel_background=pn.element_rect(fill=fill),
        plot_background=pn.element_rect(fill=fill, color="none"),
    )


def palette(target: Target = "typst") -> list[str]:
    """Discrete colours for `target`: PALETTE, or the terminal's ANSI colours in the
    same hues if it says them."""
    colors = target == "terminal" and terminal_colors()
    return [colors.ansi[n] for n in _ANSI_PALETTE] if colors else PALETTE


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


def show_terminal(
    figure: pn.ggplot,
    max_columns: int = 80,
    stream: TextIO | None = None,
) -> None:
    """
    Draw `figure` in the terminal (`stream`, stdout by default) with kitty's graphics
    protocol.

    It's drawn as wide as the terminal, up to `max_columns`, with text the size of
    the terminal's (see `_terminal_size`). Pair it with `theme_ali(target="terminal")`
    and `palette("terminal")`. Check `alipatti.terminal.shows_kitty_graphics` first:
    other terminals print the escapes as garbage.
    """
    stream = stream or sys.stdout
    columns = min(shutil.get_terminal_size().columns, max_columns)

    figure = figure + _terminal_size(figure, columns, _cell_pixels(stream))
    png = _render_png(figure, transparent=terminal_colors() is None)

    stream.write("\n" + _kitty_escapes(png, columns) + "\n")
    stream.flush()


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
    panel, and use that as the right margin. In a composition, centered top and
    bottom legends are then centered on all the panels (see
    `_center_composition_legends`).
    """
    with _drawn(figure) as (_, drawn):
        left = min(axes.get_position().x0 for axes in drawn.axes)

    margin = pn.theme(plot_margin_right=left)

    if isinstance(figure, Compose):
        return _center_composition_legends(figure & margin)

    return figure + margin


@contextmanager
def _drawn[F: Figure](figure: F) -> Generator[tuple[F, MplFigure]]:
    """A laid-out copy of `figure` and its matplotlib figure, closed on exit."""
    copy = deepcopy(figure)  # drawing mutates the figure, so draw a copy
    drawn = copy.draw()
    drawn.draw_without_rendering()  # run plotnine's layout engine

    try:
        yield copy, drawn
    finally:
        plt.close(drawn)


def _leaf_plots(composition: Compose) -> Iterator[pn.ggplot]:
    """The plots in `composition`, in the order plotnine draws them."""
    for item in composition:
        if isinstance(item, pn.ggplot):
            yield item
        elif item:
            yield from _leaf_plots(item)


def _center_composition_legends(composition: Compose) -> Compose:
    """
    Center each centered top or bottom legend in `composition` on all its panels.

    Plotnine centers such a legend on its own plot's panels, which in a composition
    leaves a legend meant for the whole figure (e.g. one shared legend under the
    last row) off to the side. Legends with any other justification are left alone.
    """
    with _drawn(composition) as (copy, drawn):
        panels = [axes.get_position() for axes in drawn.axes]
        center = (min(p.x0 for p in panels) + max(p.x1 for p in panels)) / 2
        themes = [_legend_centering(spec.plot, center) for spec in copy.plotspecs]

    composition = deepcopy(composition)
    for plot, theme in zip(_leaf_plots(composition), themes, strict=True):
        plot += theme

    return composition


def _legend_centering(plot: pn.ggplot, center: float) -> pn.theme:
    """
    The justifications that center drawn `plot`'s centered top and bottom legends at
    `center` (in figure coordinates).

    Plotnine puts a legend of width w with justification j at
    `low + j * (high - w - low)`, where low and high bound the plot's panels. It
    doesn't clip j to [0, 1], so the legend can reach past them.
    """
    figure_width = plot.figure.bbox.width
    low = min(axes.get_position().x0 for axes in plot.axs)
    high = max(axes.get_position().x1 for axes in plot.axs)
    legends = getattr(plot.theme.targets, "legends", None)

    justifications = {}
    for side in ("top", "bottom"):
        legend = legends and getattr(legends, side)

        if not legend or legend.justification != 0.5:
            continue

        width = legend.box.get_window_extent().width / figure_width
        justification = (center - width / 2 - low) / (high - width - low)
        justifications[f"legend_justification_{side}"] = justification

    return pn.theme(**justifications)


def _terminal_size(
    figure: pn.ggplot,
    columns: int,
    cell: tuple[float, float] | None,
    cell_per_em: float = 1.25,
    fallback_dpi: float = 200,
) -> pn.theme:
    """
    The figure size and dpi that draw `figure` `columns` cells wide.

    The dpi makes the theme's text size as tall as the terminal's text (a cell is
    about `cell_per_em` times its font's size), and the figure is rescaled (keeping
    its aspect ratio) to be `columns` cells wide at that dpi, so each image pixel is
    one screen pixel. Without the cell's size, only the dpi is set, to
    `fallback_dpi`, and kitty scales the image.
    """
    if cell is None:
        return pn.theme(dpi=fallback_dpi)

    cell_width, cell_height = cell
    text_size = figure.theme.getp(("text", "size"))
    dpi = cell_height / cell_per_em * _POINTS_PER_INCH / text_size
    width, height = figure.theme.getp("figure_size")
    new_width = columns * cell_width / dpi
    return pn.theme(
        figure_size=(new_width, height * new_width / width),
        dpi=dpi,
    )


def _render_png(figure: pn.ggplot, transparent: bool = False) -> bytes:
    """`figure` as a png, at its theme's dpi."""
    buffer = BytesIO()
    figure.save(buffer, format="png", transparent=transparent, verbose=False)
    return buffer.getvalue()
