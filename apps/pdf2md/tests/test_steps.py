from pathlib import Path

import pytest
from pydantic import BaseModel

import pdf2md.cache
from pdf2md.cache import cached
from pdf2md.document import Document
from pdf2md.steps.marker import split_pages
from pdf2md.steps.pdftotext import to_markdown
from pdf2md.steps.rumdl import Rumdl


def test_split_pages() -> None:
    """Split marker's paginated output into 1-indexed pages."""
    separator = "-" * 48
    markdown = f"\n\n{{0}}{separator}\n\nfirst\n\n{{1}}{separator}\n\nsecond\n"

    assert split_pages(markdown) == {1: "first", 2: "second"}


@pytest.mark.parametrize(
    ("page", "expected"),
    [
        ("a paragraph\nwrapped here\n\nanother", "a paragraph wrapped here\n\nanother"),
        ("a charac-\nterization", "a characterization"),
        ("well-known and X-\nRay", "well-known and X- Ray"),
        ("intro\n• first\n• second", "intro\n\n- first\n\n- second"),
        ("intro\n1. one\n2. two", "intro\n\n1. one\n\n2. two"),
        ("costs $5, a*b, snake_case", r"costs \$5, a\*b, snake\_case"),
        ("#tag <b> [1] `x` |", r"\#tag \<b\> \[1\] \`x\` \|"),
        ("- not a list", r"\- not a list"),
    ],
)
def test_pdftotext_to_markdown(page: str, expected: str) -> None:
    """Join wrapped lines, mark list items, and escape markdown characters."""
    assert to_markdown(page) == expected


def test_rumdl_keeps_page_markers_and_math() -> None:
    """Break lines semantically without touching page markers or math."""
    markdown = (
        "<!-- page 1 -->\n\nOne sentence here. Another one with $x_i^2$ in it.\n\n"
        "$$\n\\sum_i x_i\n$$\n"
    )
    document = Document(markdown=markdown, pdf=Path("unused.pdf"))

    result = Rumdl().run(document, Path()).document.markdown

    assert result == (
        "<!-- page 1 -->\n\nOne sentence here.\nAnother one with $x_i^2$ in it.\n\n"
        "$$\n\\sum_i x_i\n$$\n"
    )


class Output(BaseModel):
    value: int


def test_cached(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    """Compute an output once per key, and redo computations that didn't finish."""
    monkeypatch.setattr(pdf2md.cache, "CACHE_DIR", tmp_path)
    calls = []

    def compute(out: Path) -> Output:
        calls.append(out)
        return Output(value=len(calls))

    assert cached({"k": 1}, compute, Output) == (Output(value=1), False)
    assert cached({"k": 1}, compute, Output) == (Output(value=1), True)
    assert cached({"k": 2}, compute, Output) == (Output(value=2), False)

    # an interrupted computation leaves no output.json
    (calls[0] / "output.json").unlink()
    assert cached({"k": 1}, compute, Output) == (Output(value=3), False)
