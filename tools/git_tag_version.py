#!/usr/bin/env python3
"""git post-commit hook: tag the commit when a python package's version changes.

compares [project].version in pyproject.toml between HEAD and its first parent
and, if it changed, creates an annotated tag v<version> on HEAD. does nothing
in repos without a pyproject.toml. requires python 3.11+ for tomllib.
"""

from __future__ import annotations

import subprocess
import sys

import tomllib


def git(*args: str) -> str | None:
    """run a git command and return its stdout, or None if it fails."""
    result = subprocess.run(["git", *args], capture_output=True, text=True, check=False)
    if result.returncode != 0:
        return None
    return result.stdout.strip()


def get_version(commit: str) -> str | None:
    """the package version committed at `commit`, or None if there is none.

    None covers a missing commit (e.g. HEAD~1 on the first commit), a commit
    without a pyproject.toml, and a pyproject.toml with no static version.
    """
    pyproject = git("show", f"{commit}:pyproject.toml")
    if pyproject is None:
        return None

    try:
        version = tomllib.loads(pyproject).get("project", {}).get("version")
    except tomllib.TOMLDecodeError as e:
        print(f"git_tag_version: could not parse pyproject.toml at {commit}: {e}")
        return None

    return version if isinstance(version, str) else None


def main() -> int:
    current_version = get_version("HEAD")
    if current_version is None:
        return 0  # not a python project, or the version is not declared statically

    old_version = get_version("HEAD~1")
    if current_version == old_version:
        return 0

    tag = f"v{current_version}"
    if git("rev-parse", "--verify", "--quiet", f"refs/tags/{tag}") is not None:
        print(
            f"version changed ({old_version or 'none'} -> {current_version}) but tag {tag} already exists"
        )
        return 0

    print(
        f"version changed ({old_version or 'none'} -> {current_version}), tagging {tag}"
    )
    subprocess.check_call(["git", "tag", "--annotate", "--message", tag, tag])
    return 0


if __name__ == "__main__":
    sys.exit(main())
