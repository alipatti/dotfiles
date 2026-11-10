import os
import re
from itertools import batched
from pathlib import Path

import pypdfium2

PAGE_IMAGE_DPI: int = 110

PAGE_SEPARATOR = re.compile(r"\n\n\{(\d+)\}-{48}\n\n")
PAGE_MARKER = "<!-- page"
IMAGE_LINK = re.compile(r"!\[[^\]]*\]\(([^)]+)\)")


def run_marker(pdf: Path, out: Path, force_ocr: bool) -> str:
    """Run marker with page separators, save its images into `out`, and return its markdown."""
    # surya runs its ocr model in llama-server, or with an nvidia gpu by default in vllm
    # through docker, which needs the nvidia container toolkit
    os.environ.setdefault("SURYA_INFERENCE_BACKEND", "llamacpp")

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
