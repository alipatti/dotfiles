import io
import sys

import matplotlib.pyplot as plt
import pandas as pd
import plotnine as pn
import pytest
from matplotlib.transforms import Bbox
from plotnine.composition import Compose

from alipatti import plot
from alipatti.plot import (
    PALETTE,
    _terminal_size,
    center_panels,
    palette,
    show_terminal,
    theme_ali,
)
from alipatti.terminal import TerminalColors

DARK: TerminalColors = TerminalColors(
    foreground="#c0caf5",
    background="#1a1b26",
    ansi=tuple(f"#0000{n:02x}" for n in range(16)),
)


@pytest.fixture
def figure() -> pn.ggplot:
    data = pd.DataFrame({"x": [1, 2, 3]})
    return (
        pn.ggplot(data, pn.aes("x", "x"))
        + pn.geom_point()
        + pn.theme_classic(base_size=11)
        + pn.theme(figure_size=(8, 6))
    )


@pytest.fixture
def dark_terminal(monkeypatch: pytest.MonkeyPatch) -> None:
    """Pretend the terminal says it's `DARK`."""
    monkeypatch.setattr(plot, "terminal_colors", lambda: DARK)


@pytest.fixture
def silent_terminal(monkeypatch: pytest.MonkeyPatch) -> None:
    """Pretend the terminal doesn't say its colours."""
    monkeypatch.setattr(plot, "terminal_colors", lambda: None)


@pytest.mark.usefixtures("dark_terminal")
def test_terminal_theme_takes_the_terminal_colours() -> None:
    """Draw text in the terminal's foreground on its background."""
    theme = theme_ali(target="terminal")

    assert theme.getp(("axis_text", "color")) == DARK.foreground
    assert theme.getp(("plot_background", "facecolor")) == DARK.background


@pytest.mark.usefixtures("dark_terminal")
def test_terminal_theme_keeps_strips_unboxed() -> None:
    """Leave the facet strips without a background, as for typst."""
    assert theme_ali(target="terminal").T.is_blank("strip_background")


@pytest.mark.usefixtures("silent_terminal")
def test_terminal_theme_is_transparent_without_colours() -> None:
    """Leave the background transparent when the terminal doesn't say its colours."""
    assert theme_ali(target="terminal").getp(("plot_background", "facecolor")) == "none"


@pytest.mark.usefixtures("dark_terminal")
def test_terminal_palette_uses_the_ansi_colours() -> None:
    """Take red, blue, cyan, yellow, magenta and green from the terminal."""
    assert palette("terminal") == [DARK.ansi[n] for n in (1, 4, 6, 3, 5, 2)]


@pytest.mark.usefixtures("silent_terminal")
def test_terminal_palette_falls_back() -> None:
    """Use PALETTE when the terminal doesn't say its colours."""
    assert palette("terminal") == PALETTE


@pytest.mark.usefixtures("dark_terminal")
def test_terminal_size_matches_the_cells(figure: pn.ggplot) -> None:
    """Scale the dpi so text is a cell high and the figure so it's `columns` cells
    wide, keeping its aspect ratio."""
    sizing = _terminal_size(figure, columns=100, cell=(10.0, 20.0))

    dpi = 20 / 1.25 * 72 / 11
    assert sizing.getp("dpi") == pytest.approx(dpi)
    assert sizing.getp("figure_size") == pytest.approx((1000 / dpi, 750 / dpi))


@pytest.mark.usefixtures("dark_terminal")
def test_terminal_size_without_the_cells(figure: pn.ggplot) -> None:
    """Only set the dpi when the terminal doesn't say its cell size."""
    sizing = _terminal_size(figure, columns=100, cell=None)

    assert sizing.getp("dpi") == 200
    assert sizing.getp("figure_size") is None


@pytest.mark.usefixtures("dark_terminal")
def test_show_terminal_writes_a_kitty_image(
    figure: pn.ggplot,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """Write the figure as a png in kitty's graphics escapes to stdout, as it is when
    called."""
    stdout = io.StringIO()
    monkeypatch.setattr(sys, "stdout", stdout)

    show_terminal(figure)

    assert stdout.getvalue().startswith("\n\x1b_Gf=100,a=T,c=")


@pytest.fixture
def bare() -> pn.ggplot:
    data = pd.DataFrame({"x": [1, 2, 3], "group": ["a", "b", "c"]})
    return pn.ggplot(data, pn.aes("x", "x")) + pn.geom_point()


def _with_legend(plot: pn.ggplot, side: str, **theme: float) -> pn.ggplot:
    return plot + pn.aes(color="group") + pn.theme(legend_position=side, **theme)


def _drawn_center_panels(
    composition: Compose,
    *,
    center_shared_legend: bool = True,
) -> tuple[list[Bbox], list[Bbox]]:
    """The panel and legend extents of `center_panels(composition)`, in figure
    coordinates and drawing order."""
    centered = center_panels(composition, center_shared_legend=center_shared_legend)
    figure = centered.draw()
    figure.draw_without_rendering()

    panels = [axes.get_position() for axes in figure.axes]
    legends = [
        artist.get_window_extent().transformed(figure.transFigure.inverted())
        for artist in figure.artists
        if hasattr(artist, "xy_loc")
    ]
    plt.close(figure)

    return panels, legends


def _center(box: Bbox) -> float:
    return (box.x0 + box.x1) / 2


@pytest.mark.parametrize("side", ["top", "bottom"])
def test_center_panels_centers_a_shared_legend(bare: pn.ggplot, side: str) -> None:
    """Center a lone centered legend on all of a composition's panels, not just its
    own plot's."""
    composition = (bare | bare) / (_with_legend(bare, side) | bare)

    panels, (legend,) = _drawn_center_panels(composition)

    center = (min(p.x0 for p in panels) + max(p.x1 for p in panels)) / 2
    assert _center(legend) == pytest.approx(center, abs=1e-3)


def test_center_panels_leaves_per_plot_legends_alone(bare: pn.ggplot) -> None:
    """Keep each legend under its own plot when several plots have a legend on the
    same side."""
    legend = _with_legend(bare, "bottom")

    panels, legends = _drawn_center_panels(legend | legend)

    for panel, box in zip(panels, legends, strict=True):
        assert _center(box) == pytest.approx(_center(panel), abs=1e-3)


def test_center_panels_leaves_uncentered_legends_alone(bare: pn.ggplot) -> None:
    """Keep a lone legend where it is if it isn't centered."""
    legend = _with_legend(bare, "bottom", legend_justification_bottom=0)
    composition = (bare | bare) / (legend | bare)

    panels, (box,) = _drawn_center_panels(composition)

    assert box.x0 == pytest.approx(panels[2].x0, abs=1e-3)


def test_center_panels_can_leave_a_shared_legend_alone(bare: pn.ggplot) -> None:
    """Keep a lone legend under its own plot without `center_shared_legend`."""
    composition = (bare | bare) / (_with_legend(bare, "bottom") | bare)

    panels, (legend,) = _drawn_center_panels(composition, center_shared_legend=False)

    assert _center(legend) == pytest.approx(_center(panels[2]), abs=1e-3)
