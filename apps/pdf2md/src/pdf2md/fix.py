import re
import shutil
import subprocess
from concurrent.futures import ThreadPoolExecutor
from itertools import batched
from pathlib import Path

import pypdfium2
from loguru import logger

from pdf2md.codex import OPENAI_MODEL, Fix, run_codex
from pdf2md.pages import IMAGE_LINK, PAGE_MARKER, join_pages, render_pages

PAGES_PER_CHUNK: int = 2
PASSES: int = 2  # passes after the first only run while some lines still look garbled

DESCRIPTION_LABEL = "*Generated figure description:*"
BARE_DOLLAR = re.compile(r"(?<!\\)\$")

LINE_PREFIX = re.compile(r"^\d+!?\| ", re.MULTILINE)
WORD = re.compile(r"[a-zA-Z]{3,}")

# spans that are fine as far as math goes: footnote markers (linked or at the start of a
# footnote), latex (but not escaped currency), links, html anchors, and minus signs in
# numbers
CLEAN_SPANS = re.compile(
    r"(?:\[|^|</span>)<sup>[^<]{1,4}</sup>"
    r"|(?<!\\)\$\$.*?(?<!\\)\$\$|(?<!\\)\$[^$]+(?<!\\)\$"
    r"|\]\([^)]*\)|</?span[^>]*>|−(?=\s?\d)"
)
GARBLED_MATH = re.compile(r"<su[bp]>|[Α-ωϕ′ℓˆ˜←-⇿∀-⋿]")

PROMPT = """\
Below is a machine transcription (marker OCR) of pages {first}-{last} of a PDF, one line per
paragraph, prefixed with line numbers. The attached images are, in order, {images}.

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
- Write math only as $...$ or $$...$$, never \\( \\) or \\[ \\]. A literal dollar sign
  (currency) must stay escaped as `\\$`.
- The transcription escapes markdown characters such as `\\_`, `\\*`, and `\\(` in prose.
  Leave those, all links and image links, citations, and author blocks as they are.
- Every row of a table, header included, must have the same number of cells.

{figures}

{lines}
"""

FIGURES_TASK = """\
For each figure image ({names}), write a description in `figures` whose purpose is to make
the figure findable by search, not to describe it perfectly: say what kind of figure it is,
what it is about, and its main takeaway, using the terms someone would search for
(variables, outcomes, methods, places, time periods). One to three sentences; exact values
aren't needed."""

NO_FIGURES_TASK = "Leave `figures` empty."


def is_garbled(line: str) -> bool:
    return bool(GARBLED_MATH.search(CLEAN_SPANS.sub("", line)))


def numbered(lines: list[str]) -> str:
    """The non-empty lines prefixed with their index, and `!` if they look garbled."""
    return "\n".join(
        f"{i}{'!' if is_garbled(line) else ''}| {line}"
        for i, line in enumerate(lines)
        if line.strip()
    )


def fix_chunk(
    pages: dict[int, str],
    page_images: list[str],
    figures: list[str],
    directory: Path,
) -> str:
    """Have the LLM fix one chunk of pages and describe its figures; return the markdown.

    Passes after the first only run while some lines still look garbled, since cheap models
    sometimes skip lines or whole chunks, and only the first pass describes figures.
    """
    first, last = min(pages), max(pages)
    lines = join_pages(pages).splitlines()
    descriptions = {}
    applied = 0

    for n in range(PASSES):
        if n and not any(map(is_garbled, lines)):
            break

        describe = not n and figures
        images = page_images + figures if describe else page_images
        prompt = PROMPT.format(
            first=first,
            last=last,
            images=", ".join(images),
            figures=(
                FIGURES_TASK.format(names=", ".join(figures))
                if describe
                else NO_FIGURES_TASK
            ),
            lines=numbered(lines),
        )
        (directory / f"prompt-{n}.md").write_text(prompt)

        try:
            response = run_codex(prompt, images, directory)
        except subprocess.TimeoutExpired:
            logger.warning(f"Pages {first}-{last} stalled twice, keeping them as is")
            break

        lines, pass_applied = apply_fixes(lines, response.fixes)
        applied += pass_applied
        if describe:
            descriptions = {
                f.image: f.description for f in response.figures if f.image in figures
            }

    logger.info(
        f"Pages {first}-{last}: {applied} fixes, "
        f"{len(descriptions)}/{len(figures)} figures described"
    )
    return "\n".join(add_descriptions(lines, descriptions)) + "\n"


def apply_fixes(lines: list[str], fixes: list[Fix]) -> tuple[list[str], int]:
    """Replace line ranges with the fixes' text and return the new lines and fixes applied.

    Fixes that overlap an earlier fix, cross a page marker, or don't fit the lines they
    replace are skipped.
    """
    result = []
    position = applied = 0

    for fix in sorted(fixes, key=lambda f: f.start):
        original = lines[fix.start : fix.end + 1]
        if (
            not position <= fix.start <= fix.end < len(lines)
            or any(line.startswith(PAGE_MARKER) for line in original)
            or not fits(fix.text, original)
        ):
            continue

        # models sometimes echo the `N!| ` prefixes back
        result += [
            *lines[position : fix.start],
            *LINE_PREFIX.sub("", fix.text).split("\n"),
        ]
        position = fix.end + 1
        applied += 1

    return result + lines[position:], applied


def fits(text: str, original: list[str]) -> bool:
    """Whether `text` plausibly replaces `original`, to catch fixes at the wrong lines.

    Math-only text must replace math, garbled, or table lines. Otherwise most words
    outside math in the shorter of the two must appear in the other, which allows restoring
    missing words.
    """
    new = set(WORD.findall(CLEAN_SPANS.sub("", text)))
    old = set(WORD.findall(" ".join(original)))

    if not new:
        return any(
            is_garbled(line) or line.lstrip().startswith(("$$", "|"))
            for line in original
        )

    return not old or len(new & old) / min(len(new), len(old)) >= 0.5


def add_descriptions(lines: list[str], descriptions: dict[str, str]) -> list[str]:
    """Insert each figure's labeled description below its image link."""
    result = []
    for line in lines:
        result.append(line)
        for image in IMAGE_LINK.findall(line):
            if image in descriptions:
                # descriptions mention currency, which markdown would read as math
                description = BARE_DOLLAR.sub(r"\\$", descriptions[image])
                result += ["", f"> {DESCRIPTION_LABEL} {description}"]

    return result


def fix_pages(
    pdf: Path,
    pages: dict[int, str],
    marker_dir: Path,
    work_dir: Path,
) -> str:
    """Fix all chunks of pages in parallel and return the joined markdown."""
    chunks = [dict(chunk) for chunk in batched(pages.items(), PAGES_PER_CHUNK)]
    directories = [work_dir / f"chunk-{i:02}" for i in range(len(chunks))]

    # pdfium isn't thread-safe, so render every page before starting the llm calls
    document = pypdfium2.PdfDocument(pdf)
    page_images = [
        render_pages(document, list(c), d) for c, d in zip(chunks, directories)
    ]

    # copy each chunk's figures next to its page images so codex can attach them
    figures = [IMAGE_LINK.findall(join_pages(c)) for c in chunks]
    for names, directory in zip(figures, directories):
        for name in names:
            shutil.copy(marker_dir / name, directory / name)

    logger.info(
        f"Fixing {len(pages)} pages in {len(chunks)} chunks with {OPENAI_MODEL}"
    )
    with ThreadPoolExecutor(len(chunks)) as pool:
        return "\n".join(pool.map(fix_chunk, chunks, page_images, figures, directories))
