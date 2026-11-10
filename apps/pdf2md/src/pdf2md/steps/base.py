import inspect
from abc import ABC, abstractmethod
from collections.abc import Iterable
from dataclasses import dataclass
from pathlib import Path

from pydantic import BaseModel, Field

from pdf2md.cache import code_digest
from pdf2md.document import PAGE_COMMENT, Document
from pdf2md.steps.llm import Strict, run_codex


class Fix(Strict):
    """Replace lines `start` through `end` (inclusive) with `text`."""

    start: int
    end: int
    text: str
    reason: str = Field(description="What was wrong, in a few words.")


class FixRecord(BaseModel):
    """A fix a step proposed, kept so its edits can be reviewed."""

    applied: bool
    """Whether it passed the checks in `Fixer.run`."""
    original: list[str]
    fix: Fix


class StepResult(BaseModel):
    document: Document
    records: list[FixRecord] = []


class Step(ABC):
    """Turns one document into the next. The first step gets an empty one with its PDF."""

    def key(self) -> dict:
        """What determines the output besides the input; the output is cached by it."""
        code = code_digest(
            inspect.getfile(type(self)),
            "steps/base.py",
            "steps/llm.py",
            "document.py",
        )
        return {"class": type(self).__name__, "fields": vars(self), "code": code}

    @abstractmethod
    def run(self, document: Document, out: Path) -> StepResult:
        """Make the next document, writing any files it refers to (e.g. figures) into `out`."""


class Fixer(Step):
    """A step that proposes fixes to lines, which `run` checks and applies."""

    @abstractmethod
    def fixes(self, document: Document) -> Iterable[Fix]: ...

    def accepts(self, fix: Fix, original: list[str]) -> bool:
        """Whether `fix` plausibly belongs at the lines it replaces."""
        return True

    def run(self, document: Document, out: Path) -> StepResult:
        """Apply the proposed fixes in order of position.

        Fixes that are out of range, overlap an earlier fix, replace a page marker, or
        aren't accepted are skipped.
        """
        lines = document.lines
        result = []
        records = []
        position = 0

        for fix in sorted(self.fixes(document), key=lambda f: f.start):
            original = lines[fix.start : fix.end + 1]
            applied = (
                position <= fix.start <= fix.end < len(lines)
                and not any(map(PAGE_COMMENT.match, original))
                and self.accepts(fix, original)
            )
            records.append(FixRecord(applied=applied, original=original, fix=fix))

            if applied:
                result += [*lines[position : fix.start], *fix.text.split("\n")]
                position = fix.end + 1

        markdown = "\n".join(result + lines[position:]) + "\n"
        return StepResult(
            document=document.model_copy(update={"markdown": markdown}),
            records=records,
        )


@dataclass
class LLMFixer(Fixer):
    """A fixer that asks an LLM, through codex."""

    model: str = "gpt-6-luna"
    effort: str = "low"

    def ask[T: BaseModel](self, prompt: str, images: list[Path], output: type[T]) -> T:
        return run_codex(prompt, images, output, self.model, self.effort)
