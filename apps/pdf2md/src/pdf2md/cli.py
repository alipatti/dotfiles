import tempfile
from pathlib import Path
from typing import Annotated, Literal

from cyclopts import App, Parameter
from cyclopts.types import ExistingFile

from pdf2md.remote import Host, digest, source_digest

app = App(name="pdf2md")


@app.default
def main(
    pdfs: Annotated[list[ExistingFile], Parameter(negative=())],
    *,
    on: str,
    out: Path | None = None,
    fix: bool = True,
    force_ocr: bool = False,
    refresh: bool = False,
):
    """Convert PDFs to markdown plus figure images on another machine and print their paths.

    The PDFs and this package's source are copied to the host, which converts them and
    caches the results by each PDF's hash: marker's output once per PDF, and the fixed
    markdown once per version of the source, so reruns are instant. The markdown and its
    figures are then copied back.

    Parameters
    ----------
    pdfs
        PDFs to convert.
    on
        SSH host to do the conversion on.
    out
        Directory for the markdown and its figures, instead of a temporary one per PDF.
    fix
        Have an LLM fix garbled math and describe figures.
    force_ocr
        OCR every page, ignoring the PDF's text layer.
    refresh
        Convert again instead of using cached results.
    """
    by_hash = {digest(pdf.read_bytes()): pdf for pdf in pdfs}
    version = source_digest()

    host = Host.connect(on)
    host.upload(by_hash, version)
    host.convert(
        list(by_hash),
        version,
        flags=[
            "--fix" if fix else "--no-fix",
            "--force-ocr" if force_ocr else "--no-force-ocr",
            "--refresh" if refresh else "--no-refresh",
        ],
    )

    for pdf_hash, pdf in by_hash.items():
        directory = out or Path(tempfile.gettempdir(), "pdf2md", pdf_hash)
        print(host.download(pdf_hash, directory, pdf.stem))


@app.command(name="_convert", show=False)
def _convert(
    hashes: list[str],
    *,
    fix: bool = True,
    force_ocr: bool = False,
    refresh: bool = False,
):
    """Convert PDFs already copied to this machine's cache by `main`."""
    from pdf2md.convert import convert_pdf

    for pdf_hash in hashes:
        convert_pdf(pdf_hash, fix, force_ocr, refresh)


@app.command(name="--completions", show=False)
def completions(shell: Literal["fish", "zsh", "bash"] = "fish"):
    print(app.generate_completion(shell=shell))
