#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.12,<3.14"
# dependencies = ["marker-pdf", "cyclopts", "loguru", "pydantic"]
# ///
"""Convert a PDF to markdown plus images with marker, then have an LLM fix each chunk of pages.

Marker gets layout, tables, figures, and display math mostly right but garbles inline math.
Lines that look garbled are flagged, and the LLM returns replacements for wrong line ranges
as structured output, along with short descriptions of each figure that make it findable
by search. Models starting with "claude" run through `claude -p`, anything else through
`codex exec`.
"""

import json
import re
import shutil
import subprocess
import time
from concurrent.futures import ThreadPoolExecutor
from functools import partial
from itertools import batched, chain
from pathlib import Path

import pypdfium2
from cyclopts import App
from loguru import logger
from pydantic import BaseModel, ConfigDict

app = App()

PAGE_SEPARATOR = re.compile(r"\n\n\{(\d+)\}-{48}\n\n")
PAGE_MARKER = "<!-- page"
PAGE_IMAGE_DPI = 110
CALL_TIMEOUT = 180  # seconds; most calls take under a minute, a few stall for many

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
paragraph, prefixed with line numbers. The page images are {pages}.

Compare the transcription against the images and return fixes for wrong lines.
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
- Everything you need is in this prompt and the images. {tool_hint}

{figures}

{lines}
"""

FIGURES_TASK = """\
The figures on these pages are also attached as {names}. For each one, write a description
in `figures` whose purpose is to make the figure findable by search, not to describe it
perfectly: say what kind of figure it is, what it is about, and its main takeaway, using
the terms someone would search for (variables, outcomes, methods, places, time periods).
One to three sentences; exact values aren't needed."""

NO_FIGURES_TASK = "Leave `figures` empty."

TOOL_HINTS = {
    "claude": "Read the page images with the Read tool and nothing else.",
    "codex": "Do not run any commands.",
}


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


SCHEMA = json.dumps(Response.model_json_schema())


class Tokens(BaseModel):
    input_tokens: int
    cached_input_tokens: int
    output_tokens: int
    cost_usd: float | None = None


class Usage(Tokens):
    chunk: int
    pass_number: int
    seconds: float
    flagged_lines: int
    applied_fixes: int
    rejected_fixes: int
    described_figures: int


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


def run_claude(
    model: str,
    effort: str,
    prompt: str,
    directory: Path,
    images: list[str],
) -> tuple[Response, Tokens]:
    """Run one `claude -p` session in `directory`; it reads the images itself."""
    command = [
        "claude", "-p", prompt,
        "--model", model,
        "--effort", effort,
        "--output-format", "json",
        "--json-schema", SCHEMA,
        "--tools", "Read",
    ]  # fmt: skip
    result = json.loads(run(command, directory))
    usage = result["usage"]
    return Response.model_validate(result["structured_output"]), Tokens(
        input_tokens=usage["input_tokens"] + usage["cache_creation_input_tokens"],
        cached_input_tokens=usage["cache_read_input_tokens"],
        output_tokens=usage["output_tokens"],
        cost_usd=result["total_cost_usd"],
    )


def run_codex(
    model: str,
    effort: str,
    prompt: str,
    directory: Path,
    images: list[str],
) -> tuple[Response, Tokens]:
    """Run one `codex exec` session in `directory` with the images attached."""
    (directory / "schema.json").write_text(SCHEMA)
    command = [
        "codex", "exec", prompt,
        "--model", model,
        "--config", f'model_reasoning_effort="{effort}"',
        "--json",
        "--sandbox", "read-only",
        "--skip-git-repo-check",
        "--ephemeral",
        "--output-schema", "schema.json",
        "--output-last-message", "result.json",
        *(arg for image in images for arg in ("--image", image)),
    ]  # fmt: skip
    events = map(json.loads, run(command, directory).splitlines())
    usage = next(e["usage"] for e in events if e["type"] == "turn.completed")
    return Response.model_validate_json(
        (directory / "result.json").read_text()
    ), Tokens(
        input_tokens=usage["input_tokens"] - usage["cached_input_tokens"],
        cached_input_tokens=usage["cached_input_tokens"],
        output_tokens=usage["output_tokens"],
    )


def run(command: list[str], directory: Path) -> str:
    """Run `command` in `directory`, retrying once if it stalls past `CALL_TIMEOUT`."""
    attempt = partial(
        subprocess.run,
        command,
        cwd=directory,
        stdin=subprocess.DEVNULL,
        capture_output=True,
        text=True,
        check=True,
        timeout=CALL_TIMEOUT,
    )

    try:
        return attempt().stdout
    except subprocess.TimeoutExpired:
        logger.warning(f"{directory.name} stalled, retrying")
        return attempt().stdout


def fix_chunk(
    pages: dict[int, str],
    page_images: list[str],
    figures: list[str],
    chunk: int,
    directory: Path,
    *,
    model: str,
    effort: str,
    passes: int,
) -> tuple[str, list[Usage]]:
    """Have an LLM fix one chunk of pages and describe its figures.

    Returns the fixed markdown and per-pass usage. Passes after the first only run while
    some lines still look garbled, since cheap models sometimes skip lines or whole chunks,
    and only the first pass describes figures.
    """
    backend = "claude" if model.startswith("claude") else "codex"
    run_llm = run_claude if backend == "claude" else run_codex
    first, last = min(pages), max(pages)
    lines = join_pages(pages).splitlines()
    descriptions = {}
    usages = []

    for n in range(passes):
        flagged_lines = sum(map(is_garbled, lines))
        if n and not flagged_lines:
            break

        describe = not n and figures
        prompt = PROMPT.format(
            first=first,
            last=last,
            pages=", ".join(page_images),
            tool_hint=TOOL_HINTS[backend],
            figures=(
                FIGURES_TASK.format(names=", ".join(figures))
                if describe
                else NO_FIGURES_TASK
            ),
            lines=numbered(lines),
        )
        (directory / f"prompt-{n}.md").write_text(prompt)

        images = page_images + (figures if describe else [])
        start = time.monotonic()
        try:
            output, tokens = run_llm(model, effort, prompt, directory, images)
        except subprocess.TimeoutExpired:
            logger.warning(f"Chunk {chunk} stalled twice, keeping it as is")
            break

        lines, applied = apply_fixes(lines, output.fixes)
        if describe:
            descriptions = {
                f.image: f.description for f in output.figures if f.image in figures
            }

        usages.append(
            Usage(
                chunk=chunk,
                pass_number=n,
                seconds=time.monotonic() - start,
                flagged_lines=flagged_lines,
                applied_fixes=applied,
                rejected_fixes=len(output.fixes) - applied,
                described_figures=len(descriptions) if describe else 0,
                **tokens.model_dump(),
            )
        )

    fixed = "\n".join(add_descriptions(lines, descriptions)) + "\n"
    (directory / "chunk.md").write_text(fixed)

    logger.info(
        f"Chunk {chunk} (pages {first}-{last}): "
        f"{sum(u.applied_fixes for u in usages)} fixes in {len(usages)} passes, "
        f"{len(descriptions)}/{len(figures)} figures described"
    )
    return fixed, usages


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


@app.default
def main(
    pdf: Path,
    out: Path | None = None,
    *,
    model: str = "gpt-6-luna",
    effort: str = "low",
    pages_per_chunk: int = 2,
    passes: int = 2,
    jobs: int = 32,
    fix: bool = True,
    force_ocr: bool = False,
):
    """Convert PDF into OUT/NAME.md plus figure images.

    The raw marker output is kept as NAME.marker.md and per-pass usage in usage.jsonl.
    """
    pdf = pdf.resolve()
    out = (out or pdf.with_suffix("")).resolve()
    out.mkdir(parents=True, exist_ok=True)

    marker_path = out / f"{pdf.stem}.marker.md"
    if not marker_path.exists():
        logger.info(f"Running marker on {pdf.name}")
        start = time.monotonic()
        marker_path.write_text(run_marker(pdf, out, force_ocr))
        logger.info(f"Marker done in {time.monotonic() - start:.0f}s")

    pages = split_pages(marker_path.read_text())
    if not fix:
        (out / f"{pdf.stem}.md").write_text(join_pages(pages))
        return

    chunks = [dict(chunk) for chunk in batched(pages.items(), pages_per_chunk)]
    directories = [out / "work" / f"chunk-{i:02}" for i in range(len(chunks))]

    # pdfium isn't thread-safe, so render every page before starting the llms
    document = pypdfium2.PdfDocument(pdf)
    page_images = [
        render_pages(document, list(c), d) for c, d in zip(chunks, directories)
    ]

    # copy each chunk's figures next to its page images so either cli can read them
    figures = [IMAGE_LINK.findall(join_pages(c)) for c in chunks]
    for names, directory in zip(figures, directories):
        for name in names:
            shutil.copy(out / name, directory / name)

    logger.info(f"Fixing {len(pages)} pages in {len(chunks)} chunks with {model}")
    fix_one = partial(fix_chunk, model=model, effort=effort, passes=passes)
    with ThreadPoolExecutor(jobs) as pool:
        markdowns, chunk_usages = zip(
            *pool.map(
                fix_one, chunks, page_images, figures, range(len(chunks)), directories
            )
        )

    usages = list(chain.from_iterable(chunk_usages))
    (out / f"{pdf.stem}.md").write_text("\n".join(markdowns))
    (out / "usage.jsonl").write_text(
        "".join(u.model_dump_json() + "\n" for u in usages)
    )

    logger.info(
        f"Done: {sum(u.applied_fixes for u in usages)} fixes applied, "
        f"{sum(u.rejected_fixes for u in usages)} rejected, "
        f"{sum(u.described_figures for u in usages)} figures described, "
        f"{sum(u.input_tokens for u in usages):,} input, "
        f"{sum(u.cached_input_tokens for u in usages):,} cached input, and "
        f"{sum(u.output_tokens for u in usages):,} output tokens"
    )


if __name__ == "__main__":
    app()
