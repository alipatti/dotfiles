import signal
import sys
import tempfile
from pathlib import Path
from typing import Annotated, Literal

from cyclopts import App, ArgumentCollection, Group, Parameter
from cyclopts.types import ExistingFile

from pdf2md.machines import Host, Local, PipelineName, SourceName, digest, status

app = App(name="pdf2md")


def one_machine(arguments: ArgumentCollection) -> None:
    if len(arguments.filter_by(value_set=True)) != 1:
        raise ValueError("Pass either --local or --on HOST.")


MACHINE = Group("Machine", help="Exactly one is required.", validator=one_machine)


@app.default
def main(
    pdfs: Annotated[list[ExistingFile], Parameter(negative=())],
    *,
    on: Annotated[str | None, Parameter(group=MACHINE)] = None,
    local: Annotated[
        bool, Parameter(group=MACHINE, negative=(), show_default=False)
    ] = False,
    out: Path | None = None,
    source: SourceName = "marker",
    pipeline: PipelineName = "default",
):
    """Convert PDFs to markdown plus figure images and print their paths.

    Each step's output is cached by its inputs, so reruns only redo what changed.

    Parameters
    ----------
    pdfs
        PDFs to convert.
    on
        SSH host to convert on.
    local
        Convert on this machine.
    out
        Directory for a folder per PDF. Defaults to a temporary directory.
    source
        marker: layout, tables, and figures. ocr: marker, OCRing every page.
        pdftotext: text only, but fast.
    pipeline
        default: rule-based and LLM fixes, and figure descriptions.
        degarble: rule-based math fixes. raw: formatting only.
    """
    status(f"Hashing {len(pdfs)} PDF(s)")
    by_hash = {digest(pdf.read_bytes()): pdf for pdf in pdfs}

    machine = Host(on) if on else Local()
    machine.upload(by_hash)
    machine.convert(list(by_hash), source, pipeline)

    # a folder per PDF, since marker names figures the same way for every PDF
    for pdf_hash, pdf in by_hash.items():
        directory = (
            out / pdf.stem if out else Path(tempfile.gettempdir(), "pdf2md", pdf_hash)
        )
        print(machine.download(pdf_hash, source, pipeline, directory, pdf.stem))


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
