import hashlib
import shlex
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Literal

PROJECT_DIR = Path(__file__).parents[2]
# relative to the home directory, which is where ssh and rsync start on the host
CACHE = ".cache/pdf2md"
VENV = ".cache/python-tool-venvs/pdf2md-server"
OUTPUT_NAME = "document.md"

# fail instead of prompting for a password or hanging on an unreachable host
SSH = ["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=10"]


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()[:16]


def source_digest() -> str:
    """Hash of the source and lockfile, which names the copy uploaded to the host."""
    files = [*sorted((PROJECT_DIR / "src").rglob("*.py")), PROJECT_DIR / "uv.lock"]
    return digest(b"".join(p.read_bytes() for p in files))


# defined here rather than with the pipelines, so the client doesn't import their dependencies
PipelineName = Literal["default", "raw", "ocr", "ocr-raw"]


def run(command: list[str], action: str, capture: bool = True) -> str:
    """Run `command` and return its output, exiting if it fails.

    Uncaptured output goes to stderr, since stdout is reserved for the markdown paths.
    """
    try:
        return subprocess.run(
            command,
            check=True,
            stdout=subprocess.PIPE if capture else sys.stderr,
            text=True,
        ).stdout
    except subprocess.CalledProcessError as error:
        sys.exit(f"Failed to {action} (exit code {error.returncode}).")


def status(message: str) -> None:
    print(message, file=sys.stderr, flush=True)


@dataclass
class Host:
    """A machine that converts PDFs, reached over ssh."""

    name: str

    def rsync(self, *args: str, action: str) -> None:
        run(["rsync", "-e", shlex.join(SSH), *args], f"{action} {self.name}")

    def upload(self, pdfs: dict[str, Path], version: str) -> None:
        """Copy PDFs (by hash) and this project's source to the host, skipping copies it has."""
        status(f"Copying {len(pdfs)} PDF(s) to {self.name}")
        with tempfile.TemporaryDirectory() as staging:
            Path(staging, "pdfs").mkdir()
            for pdf_hash, pdf in pdfs.items():
                Path(staging, "pdfs", f"{pdf_hash}.pdf").symlink_to(pdf.resolve())
            Path(staging, "code").mkdir()
            Path(staging, "code", version).symlink_to(PROJECT_DIR)

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
        version: str,
        pipeline: PipelineName,
    ) -> None:
        """Run `pdf2md _convert` from the uploaded source, with its server dependencies."""
        # the source arrives read-only from the nix store, since rsync on macos can't
        # change modes, so make it writable for deleting by hand. uv resolves a relative
        # environment path against the project, so that one is absolute
        command = (
            f"chmod -R u+w {CACHE}/code/{version} && "
            f"env UV_PROJECT_ENVIRONMENT=$HOME/{VENV} "
        ) + shlex.join(
            [
                "uv", "run", "--project", f"{CACHE}/code/{version}",
                "--locked", "--extra", "server",
                "pdf2md", "_convert", *hashes, "--pipeline", pipeline,
            ]
        )  # fmt: skip
        # a terminal on the host passes ctrl-c on to the conversion, and lets marker show
        # its progress bars
        tty = ["-t"] if sys.stdin.isatty() and sys.stderr.isatty() else []
        status(f"Converting on {self.name}")
        run([*SSH, *tty, self.name, command], f"convert on {self.name}", capture=False)

    def download(
        self,
        pdf_hash: str,
        pipeline: PipelineName,
        directory: Path,
        stem: str,
    ) -> Path:
        """Copy a PDF's markdown, named `stem`, and its figures into `directory`."""
        status(f"Copying {stem}.md and its figures from {self.name}")
        directory.mkdir(parents=True, exist_ok=True)
        self.rsync(
            "-rt",
            f"{self.name}:{CACHE}/results/{pdf_hash}/{pipeline}/",
            f"{directory}/",
            action="copy the markdown from",
        )
        return (directory / OUTPUT_NAME).replace(directory / f"{stem}.md")
