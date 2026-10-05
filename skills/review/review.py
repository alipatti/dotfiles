#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.12"
# dependencies = ["cyclopts"]
# ///
"""Run every prompt in DIR/prompts through read-only claude and codex reviewers in parallel.

Reports go to DIR/reviews/<task>.<reviewer>.md and transcripts to DIR/logs/.
One line is printed per run as it finishes, then a summary line.
Must run outside the claude sandbox: both CLIs need network and their own state dirs.
"""

import asyncio
import json
import os
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Annotated, Literal

import cyclopts

type Reviewer = Literal["claude", "codex"]

PREAMBLE = Path(__file__).resolve().parent / "preamble.md"

# codex features a reviewer never needs; disabling them speeds startup and
# blocks delegation (multi_agent). keeps shell, file reading, and web search
CODEX_DISABLED = [
    "multi_agent",
    "plugins",
    "apps",
    "browser_use",
    "computer_use",
    "image_generation",
    "goals",
    "tool_suggest",
]
CLAUDE_TOOLS = ["Read", "Grep", "Glob", "Bash", "Skill"]
# dontAsk denies tools that aren't pre-approved, so these are also passed to --allowedTools
CLAUDE_WEB_TOOLS = ["WebSearch", "WebFetch"]

app = cyclopts.App(help_on_error=True)


@dataclass(frozen=True)
class Run:
    task: str
    reviewer: Reviewer
    prompt: str
    review: Path
    log: Path


def read_source(path: Path) -> str:
    """Return a file's text, converting pdfs to markdown with pdf2md (cached by hash)."""
    if path.suffix != ".pdf":
        return path.read_text()

    print(f"converting {path} with pdf2md (slow on long pdfs; cached)", file=sys.stderr)
    markdown = subprocess.run(
        ["pdf2md", path],
        check=True,
        capture_output=True,
        text=True,
    ).stdout.strip()
    return Path(markdown).read_text()


def inline_sources(repo: Path, files: list[Path]) -> str:
    """Line-numbered copies of the given files, to append to every prompt."""
    if not files:
        return ""

    blocks = [
        f'<file path="{f}">\n'
        + "".join(
            f"{i}\t{line}\n"
            for i, line in enumerate(read_source(repo / f).splitlines(), 1)
        )
        + "</file>"
        for f in files
    ]
    return "\n\nSOURCE FILES (line-numbered; cite as path:line):\n\n" + "\n\n".join(
        blocks
    )


def build_prompt(task_prompt: Path, sources: str) -> str:
    return f"{PREAMBLE.read_text()}\n\n{task_prompt.read_text()}{sources}"


def command(run: Run, repo: Path, web: bool) -> list[str]:
    if run.reviewer == "codex":
        return [
            "codex",
            *(["--search"] if web else []),
            "exec",
            "--sandbox=read-only",
            "--ephemeral",
            *(f"--disable={feature}" for feature in CODEX_DISABLED),
            f"--cd={repo}",
            f"--output-last-message={run.review}",
            "-",
        ]

    # claude has no read-only sandbox mode, so deny writes to the repo in the
    # bash sandbox and leave out the editing and delegation tools
    tools = CLAUDE_TOOLS + (CLAUDE_WEB_TOOLS if web else [])
    settings = {"sandbox": {"enabled": True, "filesystem": {"denyWrite": [str(repo)]}}}
    return [
        "claude",
        "--print",
        "--output-format=stream-json",
        "--verbose",
        "--permission-mode=dontAsk",
        "--no-session-persistence",
        f"--tools={','.join(tools)}",
        *([f"--allowedTools={','.join(CLAUDE_WEB_TOOLS)}"] if web else []),
        f"--settings={json.dumps(settings)}",
    ]


def claude_result(log: Path) -> str | None:
    """The final message from a claude stream-json transcript, or None if it errored."""
    events = [
        json.loads(line)
        for line in log.read_text().splitlines()
        if line.startswith("{")
    ]
    result = next((e for e in reversed(events) if e.get("type") == "result"), None)
    return None if result is None or result.get("is_error") else result["result"]


async def execute(run: Run, repo: Path, web: bool, timeout: float) -> str | None:
    """Run one reviewer; return None on success or a short error description."""
    # REVIEW_LEAF tells the skill it is a reviewer; unsetting CLAUDECODE lets
    # claude start when this script is itself run from claude code
    env = os.environ | {"REVIEW_LEAF": "1"}
    env.pop("CLAUDECODE", None)

    with run.log.open("w") as log:
        proc = await asyncio.create_subprocess_exec(
            *command(run, repo, web),
            cwd=repo,
            env=env,
            stdin=asyncio.subprocess.PIPE,
            stdout=log,
            stderr=subprocess.STDOUT,
        )
        try:
            await asyncio.wait_for(proc.communicate(run.prompt.encode()), timeout)
        except TimeoutError:
            proc.kill()
            await proc.wait()
            return f"timed out after {timeout / 60:.0f}m"

    if proc.returncode:
        return f"exit {proc.returncode}"

    if run.reviewer == "claude":
        report = claude_result(run.log)
        if report is None:
            return "no result in transcript"
        run.review.write_text(report)

    return None


async def run_all(runs: list[Run], repo: Path, web: bool, timeout: float) -> int:
    start = time.monotonic()
    width = max(len(r.task) for r in runs)

    async def timed(run: Run) -> tuple[Run, str | None, float]:
        error = await execute(run, repo, web, timeout)
        return run, error, time.monotonic() - start

    failures = 0
    for done in asyncio.as_completed([timed(r) for r in runs]):
        run, error, elapsed = await done
        failures += error is not None
        status, detail = (
            ("failed", f"{error}  {run.log}") if error else ("done", str(run.review))
        )
        minutes, seconds = divmod(int(elapsed), 60)
        print(
            f"{status:<6}  {run.reviewer:<6}  {run.task:<{width}}  {minutes}m{seconds:02}s  {detail}",
            flush=True,
        )

    print(f"all done: {len(runs) - failures} ok, {failures} failed", flush=True)
    return failures


@app.default
def main(
    directory: Path,
    /,
    *,
    repo: Annotated[Path, cyclopts.Parameter(name=["--repo", "-C"])] = Path("."),
    file: Annotated[
        list[Path] | None, cyclopts.Parameter(name=["--file", "-f"])
    ] = None,
    reviewers: list[Reviewer] | None = None,
    web: bool = True,
    timeout_minutes: float = 30,
):
    """Review DIRECTORY/prompts/*.md with each reviewer.

    Parameters
    ----------
    directory
        Review directory containing prompts/; reviews/ and logs/ are created next to it.
    repo
        Working directory the reviewers run in.
    file
        Files (relative to repo) to inline, line-numbered, into every prompt. Pdfs go through pdf2md.
    reviewers
        Which CLIs to run (default: claude and codex).
    web
        Allow web search and fetching. Disable with --no-web.
    timeout_minutes
        Kill a reviewer that runs longer than this.
    """
    directory, repo = directory.resolve(), repo.resolve()
    prompts = sorted((directory / "prompts").glob("*.md"))
    if not prompts:
        raise SystemExit(f"no prompts in {directory / 'prompts'}")

    for sub in ["reviews", "logs"]:
        (directory / sub).mkdir(exist_ok=True)

    sources = inline_sources(repo, file or [])
    runs = [
        Run(
            task=p.stem,
            reviewer=reviewer,
            prompt=build_prompt(p, sources),
            review=directory / "reviews" / f"{p.stem}.{reviewer}.md",
            log=directory / "logs" / f"{p.stem}.{reviewer}.log",
        )
        for p in prompts
        for reviewer in reviewers or ["claude", "codex"]
    ]

    failures = asyncio.run(run_all(runs, repo, web, timeout_minutes * 60))
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    app()
