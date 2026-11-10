import re
from dataclasses import dataclass
from itertools import batched
from pathlib import Path

from pydantic import BaseModel

PAGE_SEPARATOR = re.compile(r"\n\n\{(\d+)\}-{48}\n\n")
PAGE_MARKER = "<!-- page"
PAGE_COMMENT = re.compile(r"^<!-- page (\d+) -->$")
IMAGE_LINK = re.compile(r"!\[[^\]]*\]\(([^)]+)\)")


def split_pages(markdown: str) -> dict[int, str]:
    """Map 1-indexed page numbers to their markdown, using marker's page separators."""
    _, *parts = PAGE_SEPARATOR.split(markdown)
    return {int(n) + 1: text.strip() for n, text in batched(parts, 2)}


def join_pages(pages: dict[int, str]) -> str:
    return (
        "\n\n".join(f"{PAGE_MARKER} {n} -->\n\n{text}" for n, text in pages.items())
        + "\n"
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


class Document(BaseModel):
    """Markdown with `<!-- page N -->` markers, as passed from a source through each step."""

    markdown: str
    pdf: Path
    """The PDF it was converted from, for steps that look at the pages."""
    figures: Path | None = None
    """The folder holding the figure files the markdown links, by relative path."""

    @property
    def lines(self) -> list[str]:
        return self.markdown.splitlines()
