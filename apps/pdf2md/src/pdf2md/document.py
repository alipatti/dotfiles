import re
from collections.abc import Callable
from dataclasses import dataclass
from pathlib import Path

from pydantic import BaseModel

PAGE_COMMENT = re.compile(r"^<!-- page (\d+) -->$")
IMAGE_LINK = re.compile(r"!\[[^\]]*\]\(([^)]+)\)")

# spans that are fine as far as math goes and mustn't be edited: footnote markers (linked
# or at the start of a footnote), latex (but not escaped currency), links, and html anchors
PROTECTED_SPANS = re.compile(
    r"(?:\[|^|</span>)<sup>[^<]{1,4}</sup>"
    r"|(?<!\\)\$\$.*?(?<!\\)\$\$|(?<!\\)\$[^$]+(?<!\\)\$"
    r"|\]\([^)]*\)|</?span[^>]*>"
)
# plus minus signs in numbers, which are fine in prose
CLEAN_SPANS = re.compile(rf"{PROTECTED_SPANS.pattern}|−(?=\s?\d)")
GARBLED_MATH = re.compile(
    r"<su[bp]>|[Α-ωϕ′ℓℂℕℚℝℤˆ˜\u0302-\u0308\u20d7←-⇿∀-⋿\U0001d400-\U0001d7ff]"
)


class Document(BaseModel):
    """Markdown with `<!-- page N -->` markers, as passed from step to step."""

    markdown: str
    """Image links point at figure files by absolute path until the result is written."""
    pdf: Path
    """The PDF it was converted from, for steps that look at the pages."""

    @property
    def lines(self) -> list[str]:
        return self.markdown.splitlines()


def relink(markdown: str, target: Callable[[str], str]) -> str:
    """Replace each image link's target `t` with `target(t)`."""
    return IMAGE_LINK.sub(
        lambda link: link[0].replace(f"({link[1]})", f"({target(link[1])})"),
        markdown,
    )


def join_pages(pages: dict[int, str]) -> str:
    return (
        "\n\n".join(f"<!-- page {n} -->\n\n{text}" for n, text in pages.items()) + "\n"
    )


@dataclass(frozen=True)
class Page:
    number: int
    start: int
    """Index of the page's marker line."""
    end: int
    """Index just past the page's last line."""


def find_pages(lines: list[str]) -> list[Page]:
    """The pages in joined markdown, by the line spans between their markers."""
    starts = [
        (i, int(match[1]))
        for i, line in enumerate(lines)
        if (match := PAGE_COMMENT.match(line))
    ]
    ends = [i for i, _ in starts[1:]] + [len(lines)]
    return [Page(n, start, end) for (start, n), end in zip(starts, ends)]


def is_garbled(line: str) -> bool:
    """Whether a line has math outside LaTeX, e.g. html sub/superscripts or greek."""
    return bool(GARBLED_MATH.search(CLEAN_SPANS.sub("", line)))
