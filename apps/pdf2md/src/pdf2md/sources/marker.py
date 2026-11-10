import os
from dataclasses import dataclass
from importlib.metadata import version
from pathlib import Path

from pdf2md.document import Document, join_pages, split_pages
from pdf2md.sources.base import Source

# surya runs its ocr model in llama-server, or with an nvidia gpu by default in vllm
# through docker, which needs the nvidia container toolkit
SURYA_BACKEND = os.environ.setdefault("SURYA_INFERENCE_BACKEND", "llamacpp")


@dataclass
class Marker(Source):
    """Convert with marker, which gets layout, tables, figures and display math right."""

    ocr: bool = False
    """OCR every page, ignoring the PDF's text layer."""

    def key(self) -> dict:
        return super().key() | {
            "marker-pdf": version("marker-pdf"),
            "surya-ocr": version("surya-ocr"),
            "backend": SURYA_BACKEND,
        }

    def convert(self, pdf: Path, out: Path) -> Document:
        from marker.converters.pdf import PdfConverter
        from marker.models import create_model_dict
        from marker.output import convert_if_not_rgb, text_from_rendered

        converter = PdfConverter(
            artifact_dict=create_model_dict(),
            config={"paginate_output": True, "force_ocr": self.ocr},
        )
        markdown, _, images = text_from_rendered(converter(str(pdf)))

        for name, image in images.items():
            convert_if_not_rgb(image).save(out / name)

        markdown = join_pages(split_pages(markdown))
        return Document(markdown=markdown, pdf=pdf, figures=out)
