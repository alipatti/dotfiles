import re
import tempfile
from collections.abc import Iterable
from dataclasses import dataclass
from itertools import batched
from pathlib import Path

import pypdfium2

from pdf2md.document import CLEAN_SPANS, Document, find_pages, is_garbled
from pdf2md.steps.base import Fix, LLMFixer
from pdf2md.steps.llm import Strict, parallel

PAGES_PER_CHUNK: int = 2
PAGE_IMAGE_DPI: int = 110

LINE_PREFIX = re.compile(r"^\d+!?\| ", re.MULTILINE)
WORD = re.compile(r"[a-zA-Z]{3,}")

PROMPT = """\
Below is a machine transcription (marker OCR) of pages {first}-{last} of a PDF, one sentence or
clause per line, prefixed with line numbers. The attached images are, in order, {images}.

Compare the transcription against the page images and return fixes for wrong lines.
Lines marked `!` contain math that was not converted to LaTeX, e.g.
`<sup>L</sup>bn(<sup>θ</sup> ∗ n ; σb 2)` for `$\\widehat{{L}}_n(\\theta^*_n; \\widehat\\sigma^2)$`.
Rewrite all such math in each `!` line as LaTeX in $...$, keeping the prose identical.
Also fix any other line that is clearly wrong: display math ($$...$$) with wrong symbols or
accents, garbled or missing words, and garbled tables.

Rules:
- Each fix replaces lines `start` through `end` (inclusive) with `text`, which may span
  several lines. Most fixes are a single line (`start` = `end`). To rebuild a garbled table
  or equation that spans several lines, use one fix covering all of its lines, and nothing
  more: never let a fix overwrite a neighboring caption, note, paragraph, or page marker.
- Give the corrected text in full, without the `N| ` prefixes. Omit lines that are correct.
- Give each fix a `reason`: what was wrong, in a few words (e.g. "inline math not LaTeX").
- Only fix what the page images show. Never invent text you can't read in them.
- Write math only as $...$ or $$...$$, never \\( \\) or \\[ \\]. A literal dollar sign
  (currency) must stay escaped as `\\$`.
- The transcription escapes markdown characters such as `\\_`, `\\*`, and `\\(` in prose.
  Leave those, all links and image links, citations, and author blocks as they are.
- Every row of a table, header included, must have the same number of cells.

{lines}
"""


class Fixes(Strict):
    fixes: list[Fix]


@dataclass(frozen=True)
class Chunk:
    pages: list[int]
    start: int
    """Index of the chunk's first line in the document; fixes are relative to it."""
    lines: list[str]


@dataclass
class Codex(LLMFixer):
    """Have an LLM compare chunks of pages against their images and fix wrong lines.

    Lines that look like garbled math are flagged in the prompt. With `only_garbled`, only
    chunks that still have such lines are sent, which makes a cheap second pass for the
    lines a first pass missed.
    """

    only_garbled: bool = False

    def fixes(self, document: Document) -> Iterable[Fix]:
        lines = document.lines
        chunks = [
            Chunk(
                pages=[page.number for page in group],
                start=group[0].start,
                lines=lines[group[0].start : group[-1].end],
            )
            for group in batched(find_pages(lines), PAGES_PER_CHUNK)
        ]
        if self.only_garbled:
            chunks = [c for c in chunks if any(map(is_garbled, c.lines))]

        with tempfile.TemporaryDirectory(prefix="pdf2md-") as work:
            # pdfium isn't thread-safe, so pages are rendered before the parallel calls
            pdf = pypdfium2.PdfDocument(document.pdf)
            images = {
                n: render_page(pdf, n, Path(work))
                for chunk in chunks
                for n in chunk.pages
            }
            results = parallel(
                lambda c: self.fix_chunk(c, [images[n] for n in c.pages]),
                chunks,
                lambda c: f"pages {c.pages[0]}-{c.pages[-1]}",
            )

        for chunk, fixes in zip(chunks, results):
            for fix in fixes:
                yield fix.model_copy(
                    update={
                        "start": chunk.start + fix.start,
                        "end": chunk.start + fix.end,
                        # models sometimes echo the `N!| ` prefixes back
                        "text": LINE_PREFIX.sub("", fix.text),
                    }
                )

    def fix_chunk(self, chunk: Chunk, images: list[Path]) -> list[Fix]:
        first, last = chunk.pages[0], chunk.pages[-1]
        prompt = PROMPT.format(
            first=first,
            last=last,
            images=", ".join(image.name for image in images),
            lines=numbered(chunk.lines),
        )
        return self.ask(prompt, images, Fixes).fixes

    def accepts(self, fix: Fix, original: list[str]) -> bool:
        """Whether `text` plausibly replaces `original`, to catch fixes at the wrong lines.

        Math-only text must replace math, garbled, or table lines. Otherwise most words
        outside math in the shorter of the two must appear in the other, which allows
        restoring missing words.
        """
        new = set(WORD.findall(CLEAN_SPANS.sub("", fix.text)))
        old = set(WORD.findall(" ".join(original)))

        if not new:
            return any(
                is_garbled(line) or line.lstrip().startswith(("$$", "|"))
                for line in original
            )

        return not old or len(new & old) / min(len(new), len(old)) >= 0.5


def render_page(pdf: pypdfium2.PdfDocument, number: int, directory: Path) -> Path:
    """Render a 1-indexed page as a PNG into `directory`."""
    path = directory / f"page-{number:03}.png"
    pdf[number - 1].render(scale=PAGE_IMAGE_DPI / 72).to_pil().save(path)
    return path


def numbered(lines: list[str]) -> str:
    """The non-empty lines prefixed with their index, and `!` if they look garbled."""
    return "\n".join(
        f"{i}{'!' if is_garbled(line) else ''}| {line}"
        for i, line in enumerate(lines)
        if line.strip()
    )
