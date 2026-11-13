"""Render markdown snippets to PDFs with pandoc, convert them back, and compare the text."""

import re
from pathlib import Path

import pypandoc
import pytest

import pdf2md.cache
from pdf2md.convert import PIPELINES, SOURCES, run_pipeline
from pdf2md.remote import PipelineName, SourceName, digest

SNIPPETS = sorted((Path(__file__).parent / "roundtrip").glob("*.md"))
# a first-line comment listing sources the snippet is expected to fail with
XFAIL = re.compile(r"\A<!-- xfail: (.+) -->")
# pandoc reads snippets and output as commonmark (the flavor marker and rumdl write),
# plus dollar math and raw blocks for page breaks
FORMAT = "commonmark_x"
PDF_ARGS: dict[str, list[str]] = {
    "typst": ["--pdf-engine=typst", "--variable=page-numbering="],
    "tectonic": ["--pdf-engine=tectonic", "--variable=pagestyle=empty"],
}
LIST_MARKER = re.compile(r"^\s*(?:[-•◦‣∙*]|\d+[.)])\s+", re.MULTILINE)


@pytest.fixture(autouse=True)
def step_cache(request: pytest.FixtureRequest, monkeypatch: pytest.MonkeyPatch) -> None:
    """Cache step outputs in pytest's cache instead of the user's."""
    directory = request.config.cache.mkdir("pdf2md-steps")
    monkeypatch.setattr(pdf2md.cache, "CACHE_DIR", directory)


def render(snippet: Path, engine: str, directory: Path) -> Path:
    """The snippet as a PDF, cached by its contents and the pandoc arguments."""
    args = PDF_ARGS[engine]
    key = digest(
        "\0".join([snippet.read_text(), pypandoc.get_pandoc_version(), *args]).encode()
    )
    pdf = directory / f"{snippet.stem}-{engine}-{key}.pdf"

    if not pdf.exists():
        partial = pdf.with_suffix(".partial.pdf")
        pypandoc.convert_file(
            snippet,
            "pdf",
            format=FORMAT,
            outputfile=partial,
            extra_args=args,
        )
        partial.replace(pdf)

    return pdf


def words(markdown: str) -> list[str]:
    """The text of `markdown` as pandoc renders it in plain text, without list markers."""
    plain = pypandoc.convert_text(
        markdown,
        "plain",
        format=FORMAT,
        extra_args=["--wrap=none"],
    )
    return LIST_MARKER.sub("", plain).split()


@pytest.mark.parametrize("snippet", SNIPPETS, ids=lambda path: path.stem)
def test_roundtrip(
    snippet: Path,
    source: SourceName,
    pdf_engine: str,
    request: pytest.FixtureRequest,
) -> None:
    """Converting a rendered snippet back to markdown recovers its text."""
    markdown = snippet.read_text()

    if (xfail := XFAIL.match(markdown)) and source in xfail[1].split(", "):
        request.applymarker(pytest.mark.xfail(reason="known limitation", strict=True))

    pipeline: PipelineName = request.config.getoption("pipeline")
    pdf = render(snippet, pdf_engine, request.config.cache.mkdir("pdf2md-pdfs"))
    document = run_pipeline((SOURCES[source], *PIPELINES[pipeline]), pdf)

    assert words(document.markdown) == words(markdown)
