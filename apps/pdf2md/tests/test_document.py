import pytest

from pdf2md.document import Page, find_pages, is_garbled, join_pages, relink


@pytest.mark.parametrize(
    "line",
    [
        "x<sub>i</sub> is the outcome",
        "the parameter θ",
        "for all x ∈ X",
        "the estimate ˆθ",
        "the estimate θ̂",
        "the reals ℝ",
        "math italic 𝜃",
    ],
)
def test_flags_garbled_math(line: str) -> None:
    """Flag html scripts, greek, math symbols, accents, and math alphanumerics."""
    assert is_garbled(line)


@pytest.mark.parametrize(
    "line",
    [
        "plain prose.",
        r"latex $\theta^2$ and $$\sum_i x_i$$ is fine",
        r"currency \$5 is fine",
        "a footnote[<sup>12</sup>](#fn12)",
        "<sup>3</sup> a footnote's text",
        "[a link](https://example.com/θ)",
        "temperatures of −5 and − 3",
    ],
)
def test_passes_clean_lines(line: str) -> None:
    """Don't flag latex, escaped currency, footnotes, links, or negative numbers."""
    assert not is_garbled(line)


def test_join_and_find_pages() -> None:
    """Pages joined with markers are found again by their markers' line spans."""
    lines = join_pages({1: "first", 3: "third\n\nmore"}).splitlines()

    assert find_pages(lines) == [Page(1, 0, 4), Page(3, 4, 9)]
    assert lines[4] == "<!-- page 3 -->"


def test_relink() -> None:
    """Rewrite image targets without touching their alt text or other links."""
    markdown = "![a.png](a.png) and [link](a.png)"

    assert relink(markdown, lambda t: f"/out/{t}") == (
        "![a.png](/out/a.png) and [link](a.png)"
    )
