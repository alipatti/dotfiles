import hashlib
import os
import shlex
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass, field
from pathlib import Path
from typing import Literal

PROJECT_DIR = Path(__file__).parents[2]
# relative to the home directory, which is where ssh and rsync start on a host
CACHE = ".cache/pdf2md"
VENV = ".cache/python-tool-venvs/pdf2md-server"
OUTPUT_NAME = "document.md"

# fail instead of prompting for a password or hanging on an unreachable host
SSH = ["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=10"]


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()[:16]


def source_digest() -> str:
    """Hash of the project, which names the copy uploaded to the host."""
    files = [
        *sorted((PROJECT_DIR / "src").rglob("*.py")),
        PROJECT_DIR / "pyproject.toml",
        PROJECT_DIR / "uv.lock",
    ]
    return digest(b"".join(p.read_bytes() for p in files))


# defined here rather than with the steps, so the client doesn't import their dependencies
SourceName = Literal["marker", "ocr", "pdftotext"]
PipelineName = Literal["default", "degarble", "raw"]


def run(command: list[str], action: str, env: dict[str, str] | None = None) -> None:
    """Run `command`, exiting if it fails.

    Its output goes to stderr, since stdout is reserved for the markdown paths.
    """
    try:
        subprocess.run(command, check=True, stdout=sys.stderr, env=env)
    except subprocess.CalledProcessError as error:
        sys.exit(f"Failed to {action} (exit code {error.returncode}).")


def status(message: str) -> None:
    print(message, file=sys.stderr, flush=True)


def convert_command(
    project: str,
    hashes: list[str],
    source: SourceName,
    pipeline: PipelineName,
) -> list[str]:
    """`pdf2md _convert` run from `project`, with its server dependencies."""
    return [
        "uv", "run", "--project", project,
        "--locked", "--no-dev", "--extra", "server",
        "pdf2md", "_convert", *hashes,
        "--source", source, "--pipeline", pipeline,
    ]  # fmt: skip


def results(
    pdf_hash: str,
    source: SourceName,
    pipeline: PipelineName,
) -> str:
    """Where a conversion's markdown and figures are, relative to the cache."""
    return f"results/{pdf_hash}/{source}/{pipeline}"


class Local:
    """This machine, converting from the installed source."""

    def upload(self, pdfs: dict[str, Path]) -> None:
        """Copy PDFs (by hash) into the cache, skipping copies it has."""
        directory = Path.home() / CACHE / "pdfs"
        directory.mkdir(parents=True, exist_ok=True)

        for pdf_hash, pdf in pdfs.items():
            if not (copy := directory / f"{pdf_hash}.pdf").exists():
                shutil.copy(pdf, copy)

    def convert(
        self,
        hashes: list[str],
        source: SourceName,
        pipeline: PipelineName,
    ) -> None:
        status("Converting")
        run(
            convert_command(str(PROJECT_DIR), hashes, source, pipeline),
            "convert",
            env=os.environ | {"UV_PROJECT_ENVIRONMENT": str(Path.home() / VENV)},
        )

    def download(
        self,
        pdf_hash: str,
        source: SourceName,
        pipeline: PipelineName,
        directory: Path,
        stem: str,
    ) -> Path:
        """Copy a PDF's markdown, named `stem`, and its figures into `directory`."""
        shutil.copytree(
            Path.home() / CACHE / results(pdf_hash, source, pipeline),
            directory,
            dirs_exist_ok=True,
        )
        return (directory / OUTPUT_NAME).replace(directory / f"{stem}.md")


@dataclass
class Host:
    """A machine that converts PDFs, reached over ssh."""

    name: str
    version: str = field(default_factory=source_digest, init=False)
    """Names the copy of the source on the host, so it's uploaded once per version."""

    def rsync(self, *args: str, action: str) -> None:
        run(["rsync", "-e", shlex.join(SSH), *args], f"{action} {self.name}")

    def upload(self, pdfs: dict[str, Path]) -> None:
        """Copy PDFs (by hash) and this project's source to the host, skipping copies it has."""
        status(f"Copying {len(pdfs)} PDF(s) to {self.name}")
        with tempfile.TemporaryDirectory() as staging:
            Path(staging, "pdfs").mkdir()
            for pdf_hash, pdf in pdfs.items():
                Path(staging, "pdfs", f"{pdf_hash}.pdf").symlink_to(pdf.resolve())
            Path(staging, "code").mkdir()
            Path(staging, "code", self.version).symlink_to(PROJECT_DIR)

            self.rsync(
                "-rLt", "--ignore-existing",
                "--exclude", ".venv", "--exclude", "__pycache__",
                "--rsync-path", f"mkdir -p {CACHE} && rsync",
                f"{staging}/", f"{self.name}:{CACHE}/",
                action="copy the PDFs to",
            )  # fmt: skip

    def convert(
        self,
        hashes: list[str],
        source: SourceName,
        pipeline: PipelineName,
    ) -> None:
        """Run `pdf2md _convert` from the uploaded source, with its server dependencies."""
        # the source arrives read-only from the nix store, since rsync on macos can't
        # change modes, so make it writable for deleting by hand. uv resolves a relative
        # environment path against the project, so that one is absolute
        project = f"{CACHE}/code/{self.version}"
        command = (
            f"chmod -R u+w {project} && env UV_PROJECT_ENVIRONMENT=$HOME/{VENV} "
        ) + shlex.join(convert_command(project, hashes, source, pipeline))
        # a terminal on the host passes ctrl-c on to the conversion, and lets marker show
        # its progress bars
        tty = ["-t"] if sys.stdin.isatty() and sys.stderr.isatty() else []
        status(f"Converting on {self.name}")
        run([*SSH, *tty, self.name, command], f"convert on {self.name}")

    def download(
        self,
        pdf_hash: str,
        source: SourceName,
        pipeline: PipelineName,
        directory: Path,
        stem: str,
    ) -> Path:
        """Copy a PDF's markdown, named `stem`, and its figures into `directory`."""
        status(f"Copying {stem}.md and its figures from {self.name}")
        directory.mkdir(parents=True, exist_ok=True)
        self.rsync(
            "-rt",
            f"{self.name}:{CACHE}/{results(pdf_hash, source, pipeline)}/",
            f"{directory}/",
            action="copy the markdown from",
        )
        return (directory / OUTPUT_NAME).replace(directory / f"{stem}.md")
