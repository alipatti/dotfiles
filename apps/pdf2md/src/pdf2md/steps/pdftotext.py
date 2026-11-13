import re
import subprocess
from dataclasses import dataclass
from functools import cache
from pathlib import Path

from pdf2md.document import Document, join_pages
from pdf2md.steps.base import Step, StepResult

# a word broken across lines by hyphenation
HYPHENATED = re.compile(r"(?<=[a-z])-\n(?=[a-z])")
MARKDOWN_CHARACTER = re.compile(r"([\\`*_\[\]<>$#|])")
# a paragraph start that markdown would read as a list item
LIST_MARKER = re.compile(r"^[-+](?= )")
BULLETS = "•◦‣▪∙"
# blank lines, and line breaks before a bullet or number, which start a list item
PARAGRAPH_BREAK = re.compile(rf"\n\s*\n|\n(?=[{BULLETS}] |\d{{1,2}}\. )")
BULLET = re.compile(rf"^[{BULLETS}] ")


@dataclass
class Pdftotext(Step):
    """Extract the PDF's text layer with pdftotext.

    Much faster than marker, but there are no figures or tables, and sub/superscripts are
    flattened into the text.
    """

    def key(self) -> dict:
        return super().key() | {"pdftotext": pdftotext_version()}

    def run(self, document: Document, out: Path) -> StepResult:
        text = subprocess.run(
            ["pdftotext", "-enc", "UTF-8", document.pdf, "-"],
            capture_output=True,
            text=True,
            check=True,
        ).stdout
        # each page ends with a form feed
        pages = text.removesuffix("\f").split("\f")
        markdown = join_pages({n: to_markdown(page) for n, page in enumerate(pages, 1)})
        return StepResult(document=document.model_copy(update={"markdown": markdown}))


def to_markdown(page: str) -> str:
    """A page of plain text as escaped markdown, with a line per paragraph."""
    paragraphs = (
        HYPHENATED.sub("", paragraph).replace("\n", " ")
        for paragraph in PARAGRAPH_BREAK.split(page.strip())
    )
    return "\n\n".join(BULLET.sub("- ", escape(p)) for p in paragraphs)


def escape(paragraph: str) -> str:
    """Escape the characters in a paragraph that markdown would read as formatting."""
    escaped = MARKDOWN_CHARACTER.sub(r"\\\1", paragraph)
    return LIST_MARKER.sub(r"\\\g<0>", escaped)


@cache
def pdftotext_version() -> str:
    # it prints its version to stderr
    return subprocess.run(
        ["pdftotext", "-v"],
        capture_output=True,
        text=True,
        check=True,
    ).stderr.splitlines()[0]
