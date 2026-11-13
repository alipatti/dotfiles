from pathlib import Path

import pytest

from pdf2md.convert import PIPELINES
from pdf2md.document import Document
from pdf2md.steps.base import LLMFixer, Step

TESTS = Path(__file__).parent
DOCUMENTS = sorted([*TESTS.glob("samples/*.md"), *TESTS.glob("roundtrip/*.md")])
# every step that isn't an LLM call, one of each kind
DETERMINISTIC_STEPS = list(
    {
        repr(step): step
        for steps in PIPELINES.values()
        for step in steps
        if not isinstance(step, LLMFixer)
    }.values()
)
DETERMINISTIC_PIPELINES = {
    name: steps
    for name, steps in PIPELINES.items()
    if not any(isinstance(step, LLMFixer) for step in steps)
}


def run(steps: tuple[Step, ...], markdown: str) -> str:
    document = Document(markdown=markdown, pdf=Path("unused.pdf"))

    for step in steps:
        document = step.run(document, Path()).document

    return document.markdown


@pytest.mark.parametrize("path", DOCUMENTS, ids=lambda path: path.stem)
@pytest.mark.parametrize("step", DETERMINISTIC_STEPS, ids=repr)
def test_step_is_idempotent(step: Step, path: Path) -> None:
    """Running a deterministic step twice is the same as running it once."""
    once = run((step,), path.read_text())
    assert run((step,), once) == once


@pytest.mark.parametrize("path", DOCUMENTS, ids=lambda path: path.stem)
@pytest.mark.parametrize(
    "steps",
    DETERMINISTIC_PIPELINES.values(),
    ids=list(DETERMINISTIC_PIPELINES),
)
def test_pipeline_is_idempotent(steps: tuple[Step, ...], path: Path) -> None:
    """Running a deterministic pipeline twice is the same as running it once."""
    once = run(steps, path.read_text())
    assert run(steps, once) == once
