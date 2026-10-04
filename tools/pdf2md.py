#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.12,<3.14"
# dependencies = ["marker-pdf", "cyclopts", "loguru", "pydantic"]
# ///
"""Convert a PDF to markdown plus images with marker, then have an LLM fix each chunk of pages.

Marker gets layout, tables, figures, and display math mostly right but garbles inline math.
Lines that look garbled are flagged, and an OpenAI model (run through `codex exec` with no
tools) returns replacements for wrong line ranges as structured output, along with short
descriptions of each figure that make it findable by search.
"""

import hashlib
import json
import os
import re
import shutil
import subprocess
import time
from concurrent.futures import ThreadPoolExecutor
from itertools import batched
from pathlib import Path

import pypdfium2
from cyclopts import App
from loguru import logger
from pydantic import BaseModel, ConfigDict

OPENAI_MODEL: str = "gpt-6-luna"
REASONING_EFFORT: str = "low"
PAGES_PER_CHUNK: int = 2
PASSES: int = 2  # passes after the first only run while some lines still look garbled
CALL_TIMEOUT: int = 180  # seconds; most calls take under a minute, a few stall for many
PAGE_IMAGE_DPI: int = 110
CACHE_DIR: Path = (
    Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "pdf2md"
)

# codex features that give the model tools; it only needs the prompt and the images
CODEX_TOOLS: tuple[str, ...] = (
    "shell_tool",
    "unified_exec",
    "view_image",
    "image_generation",
    "multi_agent",
    "plugins",
    "apps",
    "browser_use",
    "computer_use",
    "sleep_tool",
    "tool_suggest",
    "skill_search",
    "goals",
)

PAGE_SEPARATOR = re.compile(r"\n\n\{(\d+)\}-{48}\n\n")
PAGE_MARKER = "<!-- page"

# spans that are fine as far as math goes: footnote markers (linked or at the start of a
# footnote), latex (but not escaped currency), links, html anchors, and minus signs in
# numbers
CLEAN_SPANS = re.compile(
    r"(?:\[|^|</span>)<sup>[^<]{1,4}</sup>"
    r"|(?<!\\)\$\$.*?(?<!\\)\$\$|(?<!\\)\$[^$]+(?<!\\)\$"
    r"|\]\([^)]*\)|</?span[^>]*>|−(?=\s?\d)"
)
GARBLED_MATH = re.compile(r"<su[bp]>|[Α-ωϕ′ℓˆ˜←-⇿∀-⋿]")

IMAGE_LINK = re.compile(r"!\[[^\]]*\]\(([^)]+)\)")
DESCRIPTION_LABEL = "*Generated figure description:*"
BARE_DOLLAR = re.compile(r"(?<!\\)\$")

LINE_PREFIX = re.compile(r"^\d+!?\| ", re.MULTILINE)
WORD = re.compile(r"[a-zA-Z]{3,}")

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

app = App()


class Strict(BaseModel):
    # structured output needs `additionalProperties: false` in the schema
    model_config = ConfigDict(extra="forbid")


class Fix(Strict):
    """Replace lines `start` through `end` (inclusive) with `text`."""

    start: int
    end: int
    text: str


class Figure(Strict):
    image: str
    description: str


class Response(Strict):
    fixes: list[Fix]
    figures: list[Figure]


def run_marker(pdf: Path, out: Path, force_ocr: bool) -> str:
    """Run marker with page separators, save its images into `out`, and return its markdown."""
    from marker.converters.pdf import PdfConverter
    from marker.models import create_model_dict
    from marker.output import convert_if_not_rgb, text_from_rendered

    converter = PdfConverter(
        artifact_dict=create_model_dict(),
        config={"paginate_output": True, "force_ocr": force_ocr},
    )
    markdown, _, images = text_from_rendered(converter(str(pdf)))

    for name, image in images.items():
        convert_if_not_rgb(image).save(out / name)

    return markdown


def split_pages(markdown: str) -> dict[int, str]:
    """Map 1-indexed page numbers to their markdown, using marker's page separators."""
    _, *parts = PAGE_SEPARATOR.split(markdown)
    return {int(n) + 1: text.strip() for n, text in batched(parts, 2)}


def join_pages(pages: dict[int, str]) -> str:
    return (
        "\n\n".join(f"{PAGE_MARKER} {n} -->\n\n{text}" for n, text in pages.items())
        + "\n"
    )


def render_pages(
    document: pypdfium2.PdfDocument,
    page_numbers: list[int],
    directory: Path,
) -> list[str]:
    """Render pages as PNGs into `directory` and return their file names."""
    directory.mkdir(parents=True, exist_ok=True)
    names = [f"page-{n:03}.png" for n in page_numbers]

    for n, name in zip(page_numbers, names):
        page = document[n - 1].render(scale=PAGE_IMAGE_DPI / 72)
        page.to_pil().save(directory / name)

    return names


def is_garbled(line: str) -> bool:
    return bool(GARBLED_MATH.search(CLEAN_SPANS.sub("", line)))


def numbered(lines: list[str]) -> str:
    """The non-empty lines prefixed with their index, and `!` if they look garbled."""
    return "\n".join(
        f"{i}{'!' if is_garbled(line) else ''}| {line}"
        for i, line in enumerate(lines)
        if line.strip()
    )


def run_codex(prompt: str, images: list[str], directory: Path) -> Response:
    """Run one tool-less `codex exec` call in `directory` and return its structured output.

    A call that stalls past `CALL_TIMEOUT` is retried once.
    """
    (directory / "schema.json").write_text(json.dumps(Response.model_json_schema()))
    command = [
        "codex", "exec", prompt,
        "--model", OPENAI_MODEL,
        "--config", f'model_reasoning_effort="{REASONING_EFFORT}"',
        *(arg for tool in CODEX_TOOLS for arg in ("--disable", tool)),
        "--ignore-user-config",
        "--ignore-rules",
        "--sandbox", "read-only",
        "--skip-git-repo-check",
        "--ephemeral",
        "--output-schema", "schema.json",
        "--output-last-message", "result.json",
        *(arg for image in images for arg in ("--image", image)),
    ]  # fmt: skip

    for attempt in range(2):
        try:
            subprocess.run(
                command,
                cwd=directory,
                stdin=subprocess.DEVNULL,
                capture_output=True,
                check=True,
                timeout=CALL_TIMEOUT,
            )
            break
        except subprocess.TimeoutExpired:
            if attempt:
                raise
            logger.warning(f"{directory.name} stalled, retrying")

    return Response.model_validate_json((directory / "result.json").read_text())


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


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()[:16]


@app.default
def main(
    pdf: Path,
    *,
    fix: bool = True,
    force_ocr: bool = False,
    refresh: bool = False,
    out: Path | None = None,
):
    """Convert PDF to markdown plus figure images and print the markdown's path.

    Results are cached in CACHE_DIR by the PDF's hash: marker's output once per PDF, and
    the fixed markdown once per version of this script, so reruns are instant and editing
    the prompt or settings reuses marker's output. `--refresh` redoes both.

    The markdown links its figures by relative path, so `--out` copies it together with
    its figures into OUT and prints that path instead.
    """
    pdf_dir = CACHE_DIR / digest(pdf.read_bytes())
    marker_dir = pdf_dir / ("marker-force-ocr" if force_ocr else "marker")
    if refresh:
        shutil.rmtree(pdf_dir, ignore_errors=True)
    marker_dir.mkdir(parents=True, exist_ok=True)

    marker_path = marker_dir / "marker.md"
    if not marker_path.exists():
        logger.info(f"Running marker on {pdf.name}")
        start = time.monotonic()
        marker_path.write_text(run_marker(pdf, marker_dir, force_ocr))
        logger.info(f"Marker done in {time.monotonic() - start:.0f}s")

    key = digest(Path(__file__).read_bytes()) if fix else "unfixed"
    markdown_path = marker_dir / f"{key}.md"

    if not markdown_path.exists():
        pages = split_pages(marker_path.read_text())
        markdown = (
            fix_pages(pdf, pages, marker_dir, pdf_dir / f"work-{key}")
            if fix
            else join_pages(pages)
        )
        markdown_path.write_text(markdown)

    if out:
        out.mkdir(parents=True, exist_ok=True)
        markdown = markdown_path.read_text()
        markdown_path = out / f"{pdf.stem}.md"
        markdown_path.write_text(markdown)
        for image in IMAGE_LINK.findall(markdown):
            shutil.copy(marker_dir / image, out / image)

    print(markdown_path)


if __name__ == "__main__":
    app()
