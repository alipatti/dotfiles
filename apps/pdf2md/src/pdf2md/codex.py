import json
import subprocess
from pathlib import Path

from loguru import logger
from pydantic import BaseModel, ConfigDict

OPENAI_MODEL: str = "gpt-6-luna"
REASONING_EFFORT: str = "low"
CALL_TIMEOUT: int = 180  # seconds; most calls take under a minute, a few stall for many

# codex features that give the model tools; it only needs the prompt and the images
CODEX_TOOLS: tuple[str, ...] = (
    "shell_tool",
    "unified_exec",
    "view_image",
    "image_generation",
    "multi_agent",
    "plugins",
    "apps",
    "browser_use",
    "computer_use",
    "sleep_tool",
    "tool_suggest",
    "skill_search",
    "goals",
)


class Strict(BaseModel):
    # structured output needs `additionalProperties: false` in the schema
    model_config = ConfigDict(extra="forbid")


class Fix(Strict):
    """Replace lines `start` through `end` (inclusive) with `text`."""

    start: int
    end: int
    text: str


class Figure(Strict):
    image: str
    description: str


class Response(Strict):
    fixes: list[Fix]
    figures: list[Figure]


def run_codex(prompt: str, images: list[str], directory: Path) -> Response:
    """Run one tool-less `codex exec` call in `directory` and return its structured output.

    A call that stalls past `CALL_TIMEOUT` is retried once.
    """
    (directory / "schema.json").write_text(json.dumps(Response.model_json_schema()))
    command = [
        "codex", "exec", prompt,
        "--model", OPENAI_MODEL,
        "--config", f'model_reasoning_effort="{REASONING_EFFORT}"',
        *(arg for tool in CODEX_TOOLS for arg in ("--disable", tool)),
        "--ignore-user-config",
        "--ignore-rules",
        "--sandbox", "read-only",
        "--skip-git-repo-check",
        "--ephemeral",
        "--output-schema", "schema.json",
        "--output-last-message", "result.json",
        *(arg for image in images for arg in ("--image", image)),
    ]  # fmt: skip

    for attempt in range(2):
        try:
            subprocess.run(
                command,
                cwd=directory,
                stdin=subprocess.DEVNULL,
                capture_output=True,
                check=True,
                timeout=CALL_TIMEOUT,
            )
            break
        except subprocess.TimeoutExpired:
            if attempt:
                raise
            logger.warning(f"{directory.name} stalled, retrying")

    return Response.model_validate_json((directory / "result.json").read_text())
