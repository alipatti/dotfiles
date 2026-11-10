import hashlib
import os
import shutil
import time
from pathlib import Path
from typing import Literal

from cyclopts import App
from loguru import logger

from pdf2md.fix import fix_pages
from pdf2md.pages import IMAGE_LINK, join_pages, run_marker, split_pages

CACHE_DIR: Path = (
    Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "pdf2md"
)
PACKAGE_DIR = Path(__file__).parent

app = App(name="pdf2md")


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()[:16]


def source_digest() -> str:
    """Hash of this package's source, so fixed markdown is cached per version."""
    return digest(b"".join(p.read_bytes() for p in sorted(PACKAGE_DIR.glob("*.py"))))


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
    the fixed markdown once per version of this package, so reruns are instant and editing
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

    if out:
        out.mkdir(parents=True, exist_ok=True)
        markdown = markdown_path.read_text()
        markdown_path = out / f"{pdf.stem}.md"
        markdown_path.write_text(markdown)
        for image in IMAGE_LINK.findall(markdown):
            shutil.copy(marker_dir / image, out / image)

    print(markdown_path)


@app.command(name="--completions", show=False)
def completions(shell: Literal["fish", "zsh", "bash"] = "fish"):
    print(app.generate_completion(shell=shell))
