from abc import ABC, abstractmethod
from pathlib import Path

from pdf2md.cache import code_digest, identity
from pdf2md.document import Document


class Source(ABC):
    """Turns a PDF into the document the steps work on."""

    def key(self) -> dict:
        """What determines the output besides the PDF; the output is cached by it."""
        return identity(self, code_digest("sources", "document.py"))

    @abstractmethod
    def convert(self, pdf: Path, out: Path) -> Document:
        """Convert `pdf`, writing any figure files into `out`."""
