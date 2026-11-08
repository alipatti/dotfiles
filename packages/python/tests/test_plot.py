import io
import sys

import pandas as pd
import plotnine as pn
import pytest

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


def test_center_panels_centers_a_composition_legend() -> None:
    """Center a centered bottom legend under all of a composition's panels, not just
    its own plot's."""
    data = pd.DataFrame({"x": [1, 2, 3], "group": ["a", "b", "c"]})
    bare = pn.ggplot(data, pn.aes("x", "x")) + pn.geom_point()
    legend = bare + pn.aes(color="group") + pn.theme(legend_position="bottom")
    composition = (bare | bare) / (legend | bare)

    figure = center_panels(composition).draw()
    figure.draw_without_rendering()
    panels = [axes.get_position() for axes in figure.axes]
    (box,) = [artist for artist in figure.artists if hasattr(artist, "xy_loc")]
    extent = box.get_window_extent().transformed(figure.transFigure.inverted())

    center = (min(p.x0 for p in panels) + max(p.x1 for p in panels)) / 2
    assert (extent.x0 + extent.x1) / 2 == pytest.approx(center, abs=1e-3)
