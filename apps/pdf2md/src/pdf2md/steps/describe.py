import re
from collections.abc import Iterable
from dataclasses import dataclass
from pathlib import Path

from pdf2md.document import IMAGE_LINK, Document, find_pages
from pdf2md.steps.base import Fix, LLMFixer
from pdf2md.steps.llm import Strict, parallel

DESCRIPTION_LABEL = "*Generated figure description:*"
BARE_DOLLAR = re.compile(r"(?<!\\)\$")

PROMPT = """\
The attached image ({image}) is a figure from a PDF. This is the text of its page:

{page}

Write a description of the figure whose purpose is to make it findable by search, not to
describe it perfectly: say what kind of figure it is, what it is about, and its main
takeaway, using the terms someone would search for (variables, outcomes, methods, places,
time periods). One to three sentences; exact values aren't needed.
"""


class Description(Strict):
    description: str


@dataclass(frozen=True)
class Figure:
    line: int
    image: Path
    page: list[str]


@dataclass
class Describe(LLMFixer):
    """Add a short, searchable description below each figure's image link."""

    def fixes(self, document: Document) -> Iterable[Fix]:
        lines = document.lines
        figures = [
            Figure(line=i, image=Path(image), page=lines[page.start : page.end])
            for page in find_pages(lines)
            for i in range(page.start, page.end)
            for image in IMAGE_LINK.findall(lines[i])
        ]
        descriptions = parallel(self.describe, figures, lambda f: f.image.name)

        # assumes one figure per line, as marker writes them
        for figure, description in zip(figures, descriptions):
            # descriptions mention currency, which markdown would read as math
            description = BARE_DOLLAR.sub(r"\\$", description)
            yield Fix(
                start=figure.line,
                end=figure.line,
                text=f"{lines[figure.line]}\n\n> {DESCRIPTION_LABEL} {description}",
                reason="figure description",
            )

    def describe(self, figure: Figure) -> str:
        prompt = PROMPT.format(image=figure.image.name, page="\n".join(figure.page))
        return self.ask(prompt, [figure.image], Description).description
