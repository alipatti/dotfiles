import shutil
import sys
import time
from pathlib import Path
from typing import get_args

from loguru import logger

from pdf2md.cache import CACHE_DIR, cached
from pdf2md.document import IMAGE_LINK, Document, relink
from pdf2md.remote import OUTPUT_NAME, PipelineName, SourceName
from pdf2md.steps.base import Step, StepResult
from pdf2md.steps.codex import Codex
from pdf2md.steps.degarble import Degarble
from pdf2md.steps.describe import Describe
from pdf2md.steps.marker import Marker
from pdf2md.steps.pdftotext import Pdftotext
from pdf2md.steps.rumdl import Rumdl

SOURCES: dict[SourceName, Step] = {
    "marker": Marker(),
    "ocr": Marker(ocr=True),
    "pdftotext": Pdftotext(),
}
# degarbling comes before the first formatting, which could break a line inside math
PIPELINES: dict[PipelineName, tuple[Step, ...]] = {
    "default": (
        Degarble(),
        Rumdl(),
        Codex(),
        Codex(only_garbled=True),
        Describe(),
        Rumdl(),
    ),
    "degarble": (Degarble(), Rumdl()),
    "raw": (Rumdl(),),
}
assert set(SOURCES) == set(get_args(SourceName))
assert set(PIPELINES) == set(get_args(PipelineName))


def configure_logging() -> None:
    logger.remove()
    logger.add(
        sys.stderr,
        format="<green>{time:HH:mm:ss}</green> {message}",
        colorize=sys.stderr.isatty(),
    )


def run_pipeline(steps: tuple[Step, ...], pdf: Path) -> Document:
    """Run each step in turn, caching each one's output by its inputs."""
    document = Document(markdown="", pdf=pdf)

    for step in steps:
        start = time.monotonic()
        result, hit = cached(
            {"input": document.model_dump(mode="json"), **step.key()},
            lambda out, step=step, document=document: step.run(document, out),
            StepResult,
        )
        document = result.document

        applied = sum(r.applied for r in result.records)
        fixes = f"{applied}/{len(result.records)} fixes, " if result.records else ""
        logger.info(f"{step!r} ({fixes}{'cached' if hit else elapsed(start)})")

    return document


def elapsed(start: float) -> str:
    return f"{time.monotonic() - start:.0f}s"


def convert_pdf(
    pdf_hash: str,
    source: SourceName,
    pipeline: PipelineName,
) -> None:
    """Convert pdfs/<hash>.pdf and write the result to results/<hash>/<source>/<pipeline>/."""
    pdf = CACHE_DIR / "pdfs" / f"{pdf_hash}.pdf"
    document = run_pipeline((SOURCES[source], *PIPELINES[pipeline]), pdf)

    result = CACHE_DIR / "results" / pdf_hash / source / pipeline
    shutil.rmtree(result, ignore_errors=True)
    result.mkdir(parents=True)
    # copy the figures beside the markdown, and link them by name
    for image in IMAGE_LINK.findall(document.markdown):
        shutil.copy(image, result)
    markdown = relink(document.markdown, lambda image: Path(image).name)
    (result / OUTPUT_NAME).write_text(markdown)
