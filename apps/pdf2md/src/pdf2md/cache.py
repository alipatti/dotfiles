import json
import shutil
from collections.abc import Callable
from functools import cache
from pathlib import Path

from pydantic import BaseModel

from pdf2md.remote import CACHE, digest

CACHE_DIR: Path = Path.home() / CACHE
PACKAGE_DIR = Path(__file__).parent


@cache
def code_digest(*paths: str) -> str:
    """Hash of the files at `paths` (files or folders; relative ones are in the package)."""
    files = sorted(
        file
        for path in map(PACKAGE_DIR.joinpath, paths)
        for file in (path.rglob("*.py") if path.is_dir() else [path])
    )
    return digest(b"".join(file.read_bytes() for file in files))


def cached[T: BaseModel](
    key: dict,
    compute: Callable[[Path], T],
    output: type[T],
) -> tuple[T, bool]:
    """Return the output stored for `key` and whether it was cached.

    Otherwise run `compute` with the entry's folder, which it may write files into, and
    store its output there. `output.json` is written last, so an interrupted
    computation is redone.
    """
    entry = CACHE_DIR / "steps" / digest(json.dumps(key, default=str).encode())
    path = entry / "output.json"

    if path.exists():
        return output.model_validate_json(path.read_text()), True

    shutil.rmtree(entry, ignore_errors=True)
    entry.mkdir(parents=True)
    result = compute(entry)
    path.write_text(result.model_dump_json())
    return result, False
