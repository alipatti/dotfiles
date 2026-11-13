from collections.abc import Iterable
from dataclasses import dataclass, field
from pathlib import Path

import pytest

from pdf2md.document import Document
from pdf2md.steps.base import Fix, Fixer
from pdf2md.steps.codex import Codex, numbered

LINES = ["<!-- page 1 -->", "", "zero", "one", "two", "three"]


@dataclass
class Proposed(Fixer):
    """A fixer that proposes fixed fixes."""

    proposed: list[Fix] = field(default_factory=list)

    def fixes(self, document: Document) -> Iterable[Fix]:
        return self.proposed


def fix(start: int, end: int, text: str) -> Fix:
    return Fix(start=start, end=end, text=text, reason="test")


def apply(*fixes: Fix) -> tuple[list[str], list[bool]]:
    """The lines after applying `fixes` to `LINES`, and which were applied."""
    document = Document(markdown="\n".join(LINES) + "\n", pdf=Path("unused.pdf"))
    result = Proposed(list(fixes)).run(document, Path())
    return result.document.lines, [record.applied for record in result.records]


def test_applies_fixes_in_order() -> None:
    """Apply fixes by position, whatever order they're proposed in."""
    lines, applied = apply(fix(4, 4, "TWO"), fix(2, 2, "ZERO"))

    assert lines == [*LINES[:2], "ZERO", "one", "TWO", "three"]
    assert applied == [True, True]


def test_replaces_ranges_with_several_lines() -> None:
    """Replace a range of lines with text of any number of lines."""
    lines, _ = apply(fix(3, 5, "a\nb"))

    assert lines == [*LINES[:3], "a", "b"]


@pytest.mark.parametrize(
    "bad",
    [
        fix(3, 4, "overlaps"),
        fix(5, 6, "out of range"),
        fix(4, 3, "backwards"),
        fix(0, 2, "replaces a page marker"),
    ],
    ids=lambda f: f.text,
)
def test_skips_bad_fixes(bad: Fix) -> None:
    """Skip fixes that overlap an earlier one, are out of range, or hit page markers."""
    lines, applied = apply(fix(2, 3, "first"), bad)

    assert lines == [*LINES[:2], "first", *LINES[4:]]
    assert sorted(applied) == [False, True]


@pytest.mark.parametrize(
    ("original", "text", "accepted"),
    [
        (["the value of θ is large"], r"the value of $\theta$ is large", True),
        (["the value is large"], "the value of it is very large indeed", True),
        (["the value is large"], "something else entirely different here", False),
        (["θ<sub>n</sub>"], r"$\theta_n$", True),
        (["$$x = y$$"], "$$x = z$$", True),
        (["plain words here"], r"$\theta_n$", False),
    ],
)
def test_codex_accepts(original: list[str], text: str, accepted: bool) -> None:
    """Accept fixes whose words mostly match, and math-only ones that replace math."""
    assert Codex().accepts(fix(0, 0, text), original) is accepted


def test_numbered_flags_garbled_lines() -> None:
    """Number non-empty lines by index, marking garbled ones with `!`."""
    assert numbered(["fine", "", "θ<sub>n</sub>"]) == "0| fine\n2!| θ<sub>n</sub>"
