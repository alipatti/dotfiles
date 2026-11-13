import signal
import sys
import tempfile
from pathlib import Path
from typing import Annotated, Literal

from cyclopts import App, Parameter
from cyclopts.types import ExistingFile

from pdf2md.remote import Host, PipelineName, SourceName, digest, status

app = App(name="pdf2md")


@app.default
def main(
    pdfs: Annotated[list[ExistingFile], Parameter(negative=())],
    *,
    on: str,
    out: Path | None = None,
    source: SourceName = "marker",
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
    source
        What makes the first draft. marker: layout, tables, figures, and display math.
        ocr: marker, but OCRing every page. pdftotext: the PDF's text layer, which is
        much faster but has no figures or tables and flattens sub/superscripts.
    pipeline
        What happens to the draft. default: rule-based math fixes, then LLM fixes and
        figure descriptions. degarble: rule-based math fixes only. raw: formatting only.
    """
    status(f"Hashing {len(pdfs)} PDF(s)")
    by_hash = {digest(pdf.read_bytes()): pdf for pdf in pdfs}

    host = Host(on)
    host.upload(by_hash)
    host.convert(list(by_hash), source, pipeline)

    # a folder per PDF, since marker names figures the same way for every PDF
    for pdf_hash, pdf in by_hash.items():
        directory = (
            out / pdf.stem if out else Path(tempfile.gettempdir(), "pdf2md", pdf_hash)
        )
        print(host.download(pdf_hash, source, pipeline, directory, pdf.stem))


@app.command(name="_convert", show=False)
def _convert(
    hashes: list[str],
    *,
    source: SourceName = "marker",
    pipeline: PipelineName = "default",
):
    """Convert PDFs already copied to this machine's cache by `main`."""
    from pdf2md.convert import configure_logging, convert_pdf

    # exit normally on hangup or kill, so surya's atexit handlers stop its servers
    for signal_number in (signal.SIGHUP, signal.SIGTERM):
        signal.signal(signal_number, lambda number, _: sys.exit(128 + number))

    configure_logging()
    for pdf_hash in hashes:
        convert_pdf(pdf_hash, source, pipeline)


@app.command(name="--completions", show=False)
def completions(shell: Literal["fish", "zsh", "bash"] = "fish"):
    print(app.generate_completion(shell=shell))
