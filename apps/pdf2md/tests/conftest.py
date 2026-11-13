from typing import get_args

import pytest

from pdf2md.remote import PipelineName, SourceName

PDF_ENGINES = ("typst", "tectonic")


def pytest_addoption(parser: pytest.Parser) -> None:
    group = parser.getgroup("pdf2md round trips")
    group.addoption(
        "--source",
        action="append",
        choices=get_args(SourceName),
        help="Source to convert the PDFs with; repeatable. Default: pdftotext.",
    )
    group.addoption(
        "--pipeline",
        default="degarble",
        choices=get_args(PipelineName),
        help="Pipeline to run after the source. Default: degarble.",
    )
    group.addoption(
        "--pdf-engine",
        action="append",
        choices=PDF_ENGINES,
        help="Engine pandoc makes the PDFs with; repeatable. Default: typst.",
    )


def pytest_generate_tests(metafunc: pytest.Metafunc) -> None:
    options = {"source": ["pdftotext"], "pdf_engine": ["typst"]}

    for name, default in options.items():
        if name in metafunc.fixturenames:
            metafunc.parametrize(name, metafunc.config.getoption(name) or default)
