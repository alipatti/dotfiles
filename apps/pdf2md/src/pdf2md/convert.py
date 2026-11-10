import shutil
import sys
import time
from pathlib import Path
from typing import get_args

from loguru import logger

from pdf2md.cache import CACHE_DIR, cached
from pdf2md.document import IMAGE_LINK, Document
from pdf2md.remote import OUTPUT_NAME, PipelineName
from pdf2md.sources.base import Source
from pdf2md.sources.marker import Marker
from pdf2md.steps.base import Step, StepResult
from pdf2md.steps.codex import Codex
from pdf2md.steps.describe import Describe
from pdf2md.steps.rumdl import Rumdl

type Pipeline = tuple[Source, tuple[Step, ...]]

FIX: tuple[Step, ...] = (
    Rumdl(),
    Codex(),
    Codex(only_garbled=True),
    Describe(),
    Rumdl(),
)
PIPELINES: dict[PipelineName, Pipeline] = {
    "default": (Marker(), FIX),
    "raw": (Marker(), (Rumdl(),)),
    "ocr": (Marker(ocr=True), FIX),
    "ocr-raw": (Marker(ocr=True), (Rumdl(),)),
}
assert set(PIPELINES) == set(get_args(PipelineName))


def configure_logging() -> None:
    logger.remove()
    logger.add(
        sys.stderr,
        format="<green>{time:HH:mm:ss}</green> {message}",
        colorize=sys.stderr.isatty(),
    )


def run_pipeline(
    pipeline: Pipeline,
    pdf: Path,
    pdf_hash: str,
) -> Document:
    """Run the source and each step in turn, caching each one's output by its inputs."""
    source, steps = pipeline

    start = time.monotonic()
    document, hit = cached(
        {"pdf": pdf_hash, **source.key()},
        lambda out: source.convert(pdf, out),
        Document,
    )
    logger.info(f"{source!r} ({'cached' if hit else elapsed(start)})")

    for step in steps:
        start = time.monotonic()
        result, hit = cached(
            {"input": document.model_dump(mode="json"), **step.key()},
            lambda _, step=step, document=document: step.run(document),
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
    pipeline: PipelineName,
) -> None:
    """Run a pipeline on pdfs/<hash>.pdf and write the result to results/<hash>/<pipeline>/."""
    pdf = CACHE_DIR / "pdfs" / f"{pdf_hash}.pdf"
    document = run_pipeline(PIPELINES[pipeline], pdf, pdf_hash)

    result = CACHE_DIR / "results" / pdf_hash / pipeline
    shutil.rmtree(result, ignore_errors=True)
    result.mkdir(parents=True)
    (result / OUTPUT_NAME).write_text(document.markdown)

    # the markdown links its figures by relative path, so they're copied beside it
    for image in IMAGE_LINK.findall(document.markdown):
        if document.figures:
            shutil.copy(document.figures / image, result / image)
