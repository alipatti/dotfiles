import json
import subprocess
import tempfile
import time
from collections.abc import Callable, Sequence
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

from loguru import logger
from pydantic import BaseModel, ConfigDict

CALL_TIMEOUT: int = 60  # seconds; most calls take seconds, a few stall for minutes
PARALLEL_CALLS: int = 16

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


def run_codex[T: BaseModel](
    prompt: str,
    images: list[Path],
    output: type[T],
    model: str,
    effort: str,
) -> T:
    """Run one tool-less `codex exec` call and return its structured output.

    A call that stalls past `CALL_TIMEOUT` is retried once, then raises `TimeoutExpired`.
    """
    command = [
        "codex", "exec", prompt,
        "--model", model,
        "--config", f'model_reasoning_effort="{effort}"',
        *(arg for tool in CODEX_TOOLS for arg in ("--disable", tool)),
        "--ignore-user-config",
        "--ignore-rules",
        "--sandbox", "read-only",
        "--skip-git-repo-check",
        "--ephemeral",
        "--output-schema", "schema.json",
        "--output-last-message", "result.json",
        *(arg for image in images for arg in ("--image", str(image.resolve()))),
    ]  # fmt: skip

    with tempfile.TemporaryDirectory(prefix="pdf2md-codex-") as directory:
        Path(directory, "schema.json").write_text(
            json.dumps(output.model_json_schema())
        )

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
                logger.warning("A codex call stalled, retrying")

        return output.model_validate_json(Path(directory, "result.json").read_text())


def parallel[T, R](
    function: Callable[[T], R],
    items: Sequence[T],
    label: Callable[[T], str],
) -> list[R]:
    """Map `function` over `items` in threads, keeping their order.

    Each call is logged as it finishes, with how many are done.
    """
    if not items:
        return []

    def timed(item: T) -> tuple[R, float]:
        start = time.monotonic()
        return function(item), time.monotonic() - start

    with ThreadPoolExecutor(min(len(items), PARALLEL_CALLS)) as pool:
        futures = {pool.submit(timed, item): item for item in items}
        for done, future in enumerate(as_completed(futures), 1):
            seconds = future.result()[1]
            logger.info(
                f"  {label(futures[future])} ({seconds:.0f}s, {done}/{len(items)})"
            )

    return [future.result()[0] for future in futures]
