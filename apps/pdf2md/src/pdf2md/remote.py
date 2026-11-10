import hashlib
import shlex
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Self

PROJECT_DIR = Path(__file__).parents[2]
OUTPUT_NAME = "document.md"

# fail instead of prompting for a password or hanging on an unreachable host
SSH = ["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=10"]


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()[:16]


def source_digest() -> str:
    """Hash of the source and lockfile, so fixed markdown is cached per version."""
    files = [*sorted((PROJECT_DIR / "src").rglob("*.py")), PROJECT_DIR / "uv.lock"]
    return digest(b"".join(p.read_bytes() for p in files))


def run(command: list[str], action: str) -> str:
    """Run `command` and return its output, exiting if it fails."""
    try:
        return subprocess.run(
            command,
            check=True,
            stdout=subprocess.PIPE,
            text=True,
        ).stdout
    except subprocess.CalledProcessError as error:
        sys.exit(f"Failed to {action} (exit code {error.returncode}).")


@dataclass
class Host:
    """A machine that converts PDFs, reached over ssh."""

    name: str
    cache: str
    """The host's cache directory, which its own `CACHE_DIR` is in."""

    @classmethod
    def connect(cls, name: str) -> Self:
        # the login shell may be fish, so posix parameter expansion goes through sh
        echo = """sh -c 'echo "${XDG_CACHE_HOME:-$HOME/.cache}"'"""
        return cls(name, run([*SSH, name, echo], f"reach {name}").strip())

    def rsync(self, *args: str, action: str) -> None:
        run(["rsync", "-e", shlex.join(SSH), *args], f"{action} {self.name}")

    def upload(self, pdfs: dict[str, Path], version: str) -> None:
        """Copy PDFs (by hash) and this project's source to the host, skipping copies it has."""
        with tempfile.TemporaryDirectory() as staging:
            inbox = Path(staging, "inbox")
            inbox.mkdir()
            for pdf_hash, pdf in pdfs.items():
                (inbox / f"{pdf_hash}.pdf").symlink_to(pdf.resolve())
            Path(staging, "code").mkdir()
            Path(staging, "code", version).symlink_to(PROJECT_DIR)

            self.rsync(
                "-rLt", "--ignore-existing",
                "--exclude", ".venv", "--exclude", "__pycache__",
                "--rsync-path", f"mkdir -p {self.cache}/pdf2md && rsync",
                f"{staging}/", f"{self.name}:{self.cache}/pdf2md/",
                action="copy the PDFs to",
            )  # fmt: skip

    def convert(self, hashes: list[str], version: str, flags: list[str]) -> None:
        """Run `pdf2md _convert` from the uploaded source, with its server dependencies."""
        command = shlex.join(
            [
                "env", f"UV_PROJECT_ENVIRONMENT={self.cache}/python-tool-venvs/pdf2md-server",
                "uv", "run", "--project", f"{self.cache}/pdf2md/code/{version}",
                "--locked", "--extra", "server",
                "pdf2md", "_convert", *hashes, *flags,
            ]
        )  # fmt: skip
        run([*SSH, self.name, command], f"convert on {self.name}")

    def download(self, pdf_hash: str, directory: Path, stem: str) -> Path:
        """Copy a PDF's markdown, named `stem`, and its figures into `directory`."""
        directory.mkdir(parents=True, exist_ok=True)
        self.rsync(
            "-rt",
            f"{self.name}:{self.cache}/pdf2md/{pdf_hash}/out/",
            f"{directory}/",
            action="copy the markdown from",
        )
        return (directory / OUTPUT_NAME).replace(directory / f"{stem}.md")
