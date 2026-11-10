import os
import shutil
import time
from pathlib import Path

from loguru import logger

from pdf2md.fix import fix_pages
from pdf2md.pages import IMAGE_LINK, join_pages, run_marker, split_pages
from pdf2md.remote import OUTPUT_NAME, source_digest

CACHE_DIR: Path = (
    Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "pdf2md"
)


def convert_pdf(pdf_hash: str, fix: bool, force_ocr: bool, refresh: bool) -> None:
    """Convert a PDF in the cache's inbox, leaving its markdown and figures in <hash>/out.

    Marker's output is cached once per PDF, and the fixed markdown once per version of the
    source, so reruns are instant and editing the prompt or settings reuses marker's
    output. `refresh` redoes both.
    """
    pdf = CACHE_DIR / "inbox" / f"{pdf_hash}.pdf"
    pdf_dir = CACHE_DIR / pdf_hash
    marker_dir = pdf_dir / ("marker-force-ocr" if force_ocr else "marker")
    if refresh:
        shutil.rmtree(pdf_dir, ignore_errors=True)
    marker_dir.mkdir(parents=True, exist_ok=True)

    marker_path = marker_dir / "marker.md"
    if not marker_path.exists():
        logger.info(f"Running marker on {pdf_hash}")
        start = time.monotonic()
        marker_path.write_text(run_marker(pdf, marker_dir, force_ocr))
        logger.info(f"Marker done in {time.monotonic() - start:.0f}s")

    key = source_digest() if fix else "unfixed"
    markdown_path = marker_dir / f"{key}.md"

    if not markdown_path.exists():
        pages = split_pages(marker_path.read_text())
        markdown = (
            fix_pages(pdf, pages, marker_dir, pdf_dir / f"work-{key}")
            if fix
            else join_pages(pages)
        )
        markdown_path.write_text(markdown)

    # the markdown links its figures by relative path, so they're copied beside it
    out = pdf_dir / "out"
    shutil.rmtree(out, ignore_errors=True)
    out.mkdir()
    markdown = markdown_path.read_text()
    (out / OUTPUT_NAME).write_text(markdown)
    for image in IMAGE_LINK.findall(markdown):
        shutil.copy(marker_dir / image, out / image)
