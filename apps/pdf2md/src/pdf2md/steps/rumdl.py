import subprocess
from dataclasses import dataclass
from importlib.metadata import version
from pathlib import Path

from pdf2md.document import Document
from pdf2md.steps.base import Step, StepResult

# semantic line breaks, so fixes replace a clause instead of a whole paragraph. inline
# settings rather than a config file, so the output doesn't depend on the host
RUMDL_SETTINGS: tuple[str, ...] = (
    "MD013.reflow = true",
    'MD013.reflow-mode = "semantic-line-breaks"',
    "MD013.line-length = 75",
    "MD013.code-blocks = false",
    "MD013.math-blocks = false",
    'global.extend-enable = ["table-format"]',
)


@dataclass
class Rumdl(Step):
    """Format the markdown with rumdl."""

    def key(self) -> dict:
        return super().key() | {"rumdl": version("rumdl")}

    def run(self, document: Document, out: Path) -> StepResult:
        formatted = subprocess.run(
            [
                "rumdl", "fmt", "--no-config", "--quiet", "-",
                *(arg for setting in RUMDL_SETTINGS for arg in ("--config", setting)),
            ],
            input=document.markdown,
            capture_output=True,
            text=True,
            check=True,
        ).stdout  # fmt: skip
        return StepResult(document=document.model_copy(update={"markdown": formatted}))
