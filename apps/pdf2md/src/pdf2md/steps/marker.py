import os
import re
from dataclasses import dataclass
from importlib.metadata import version
from itertools import batched
from pathlib import Path

from pdf2md.document import Document, join_pages, relink
from pdf2md.steps.base import Step, StepResult

PAGE_SEPARATOR = re.compile(r"\n\n\{(\d+)\}-{48}\n\n")

# surya runs its ocr model in llama-server, or with an nvidia gpu by default in vllm
# through docker, which needs the nvidia container toolkit
SURYA_BACKEND = os.environ.setdefault("SURYA_INFERENCE_BACKEND", "llamacpp")


@dataclass
class Marker(Step):
    """Convert the PDF with marker, which gets layout, tables, figures and math right."""

    ocr: bool = False
    """OCR every page, ignoring the PDF's text layer."""

    def key(self) -> dict:
        return super().key() | {
            "marker-pdf": version("marker-pdf"),
            "surya-ocr": version("surya-ocr"),
            "backend": SURYA_BACKEND,
        }

    def run(self, document: Document, out: Path) -> StepResult:
        from marker.converters.pdf import PdfConverter
        from marker.models import create_model_dict
        from marker.output import convert_if_not_rgb, text_from_rendered

        converter = PdfConverter(
            artifact_dict=create_model_dict(),
            config={"paginate_output": True, "force_ocr": self.ocr},
        )
        markdown, _, images = text_from_rendered(converter(str(document.pdf)))

        for name, image in images.items():
            convert_if_not_rgb(image).save(out / name)

        markdown = relink(
            join_pages(split_pages(markdown)), lambda name: str(out / name)
        )
        return StepResult(document=document.model_copy(update={"markdown": markdown}))


def split_pages(markdown: str) -> dict[int, str]:
    """Map 1-indexed page numbers to their markdown, using marker's page separators."""
    _, *parts = PAGE_SEPARATOR.split(markdown)
    return {int(n) + 1: text.strip() for n, text in batched(parts, 2)}
