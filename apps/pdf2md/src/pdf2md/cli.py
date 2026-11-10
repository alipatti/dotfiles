import tempfile
from pathlib import Path
from typing import Annotated, Literal

from cyclopts import App, Parameter
from cyclopts.types import ExistingFile

from pdf2md.remote import Host, PipelineName, digest, status

app = App(name="pdf2md")


@app.default
def main(
    pdfs: Annotated[list[ExistingFile], Parameter(negative=())],
    *,
    on: str,
    out: Path | None = None,
    pipeline: PipelineName = "default",
):
    """Convert PDFs to markdown plus figure images on another machine and print their paths.

    The PDFs and this package's source are copied to the host, which converts them,
    caching each step's output by its inputs, so reruns only redo what changed. The
    markdown and its figures are then copied back.

    Parameters
    ----------
    pdfs
        PDFs to convert.
    on
        SSH host to do the conversion on.
    out
        Directory to put a folder in for each PDF, named after it, with its markdown
        and figures. Defaults to a temporary directory.
    pipeline
        default: marker, then LLM fixes and figure descriptions. raw: marker only.
        ocr and ocr-raw: the same, but marker OCRs every page.
    """
    status(f"Hashing {len(pdfs)} PDF(s)")
    by_hash = {digest(pdf.read_bytes()): pdf for pdf in pdfs}

    host = Host(on)
    host.upload(by_hash)
    host.convert(list(by_hash), pipeline)

    # a folder per PDF, since marker names figures the same way for every PDF
    for pdf_hash, pdf in by_hash.items():
        directory = (
            out / pdf.stem if out else Path(tempfile.gettempdir(), "pdf2md", pdf_hash)
        )
        print(host.download(pdf_hash, pipeline, directory, pdf.stem))


@app.command(name="_convert", show=False)
def _convert(
    hashes: list[str],
    *,
    pipeline: PipelineName = "default",
):
    """Convert PDFs already copied to this machine's cache by `main`."""
    from pdf2md.convert import configure_logging, convert_pdf

    configure_logging()
    for pdf_hash in hashes:
        convert_pdf(pdf_hash, pipeline)


@app.command(name="--completions", show=False)
def completions(shell: Literal["fish", "zsh", "bash"] = "fish"):
    print(app.generate_completion(shell=shell))
