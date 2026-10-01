#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.12"
# dependencies = [
#     "cyclopts>=3",
#     "httpx",
# ]
# ///
"""Canvas LMS CLI: download course files, list and submit assignments.

The course id is in the Canvas URL, e.g. /courses/22872.
To submit, run `assignments` to find the assignment id, then `submit` with it.

Authentication uses the canvas_session browser cookie (Princeton disables API
tokens). Pass it once with --cookie; it is validated and cached in
~/.cache/canvas/. When a command reports the cookie missing or expired, get a
fresh value from Safari Web Inspector (Cmd+Opt+I) > Storage > Cookies.

Every command needs network access to the Canvas host, so it may have to run
outside a sandbox. Errors are reported as one-line messages that say what went
wrong; there is no need to call the Canvas API directly.
"""

import json
import mimetypes
import pathlib
import re
from collections import Counter
from dataclasses import dataclass
from typing import Any
from urllib.parse import unquote, urlparse

import httpx
from cyclopts import App, Parameter

app = App(help=__doc__)

CACHE_DIR = pathlib.Path.home() / ".cache" / "canvas"
DEFAULT_BASE = "https://princeton.instructure.com"
ASSIGNMENT_HEADER = (
    f"{'id':>8}  {'due':<20}  {'state':<12}  {'attempt':>7}  {'types':<14}  name"
)


@Parameter(name="*")
@dataclass
class Auth:
    cookie: str | None = None
    """canvas_session cookie value. Defaults to the cached one."""

    base: str = DEFAULT_BASE
    """Canvas base URL."""


DEFAULT_AUTH = Auth()


def _parse(r: httpx.Response) -> Any:
    """Decode a Canvas API response, exiting with a readable message on failure."""
    # drop the query string, which can hold upload tokens
    request = f"{r.request.method} {r.url.copy_with(query=None)}"
    content_type = r.headers.get("content-type", "")

    if r.is_error:
        detail = f": {r.text[:300]}" if "json" in content_type else ""
        raise SystemExit(
            f"{request} failed with HTTP {r.status_code} {r.reason_phrase}{detail}"
        )

    if "json" not in content_type:
        raise SystemExit(
            f"{request} returned {content_type or 'no content type'} instead of "
            "JSON. The cookie is fine (it was validated on startup); "
            "the URL is probably not a Canvas API endpoint."
        )

    return json.loads(r.text.removeprefix("while(1);"))


class Canvas:
    """Cookie-authenticated client for the Canvas REST API."""

    def __init__(self, auth: Auth):
        self.base = auth.base.rstrip("/")
        host = urlparse(self.base).hostname or self.base
        cache = CACHE_DIR / f"canvas_session-{host}"

        if not (
            cookie := auth.cookie or (cache.is_file() and cache.read_text().strip())
        ):
            raise SystemExit(
                f"No cached cookie for {host}. Ask the user for the canvas_session "
                "value (Safari Web Inspector Cmd+Opt+I > Storage > Cookies) and "
                "pass it with --cookie."
            )

        # paths are relative to the api root; absolute urls (pagination links,
        # file downloads) bypass it
        self.http = httpx.Client(base_url=f"{self.base}/api/v1", timeout=60)
        # scoped to the canvas host so redirects to file cdns don't receive it
        self.http.cookies.set("canvas_session", cookie, domain=host)

        # an expired cookie gets a 401 or a redirect to the login page
        r = self.http.get("/users/self")
        if r.is_redirect or r.status_code in (401, 403):
            if not auth.cookie:
                cache.unlink(missing_ok=True)
            raise SystemExit(
                "Cookie is invalid or expired. Ask the user for a fresh "
                "canvas_session value and pass it with --cookie."
            )
        user = _parse(r)
        source = "--cookie" if auth.cookie else "cached cookie"
        print(f"authenticated to {host} as {user['name']} ({source})")

        # skip the rewrite when unchanged so sandboxed runs work with a cached cookie
        if auth.cookie and not (
            cache.is_file() and cache.read_text().strip() == cookie
        ):
            CACHE_DIR.mkdir(parents=True, exist_ok=True)
            cache.write_text(cookie)
            cache.chmod(0o600)

        # mutating requests need the csrf token that the get above set
        csrf = (c.value for c in self.http.cookies.jar if c.name == "_csrf_token")
        self.csrf = unquote(next(csrf, None) or "")

    def get(self, path: str, **params) -> dict:
        return _parse(self.http.get(path, params=params))

    def paginate(self, path: str, **params) -> list[dict]:
        out = []
        url: str | None = path
        params = {"per_page": 100, **params}

        while url:
            r = self.http.get(url, params=params)
            # next links already carry the query
            params = {}
            out.extend(_parse(r))
            url = r.links.get("next", {}).get("url")

        return out

    def post(self, path: str, data: dict) -> dict:
        return _parse(
            self.http.post(path, data=data, headers={"X-CSRF-Token": self.csrf})
        )

    def assignments(self, course_id: int) -> list[dict]:
        return self.paginate(
            f"/courses/{course_id}/assignments",
            **{"include[]": "submission"},
        )

    def _find_assignment(self, course_id: int, query: str) -> dict:
        """Find one assignment by id, or by name substring if QUERY isn't all digits."""
        everything = self.assignments(course_id)

        # all-digit input is only ever an id, so "4" can't match "Homework 04"
        matches = [
            a
            for a in everything
            if (
                str(a["id"]) == query
                if query.isdigit()
                else query.lower() in a["name"].lower()
            )
        ]

        if len(matches) != 1:
            kind = "id" if query.isdigit() else "name containing"
            shown = matches or everything
            raise SystemExit(
                f"Expected exactly one assignment with {kind} {query!r}, "
                f"got {len(matches)}. {'Matches' if matches else 'All assignments'}:\n"
                + "\n".join([ASSIGNMENT_HEADER, *map(_format_assignment, shown)])
                + "\nPass the numeric id from the first column."
            )

        return matches[0]

    def _download_file(self, file_id: str, folder: pathlib.Path) -> str:
        """Download a file into FOLDER, returning "new", "updated" or "unchanged"."""
        meta = self.get(f"/files/{file_id}")
        # display names come from canvas, so strip any directory components
        name = pathlib.Path(meta["display_name"]).name

        r = self.http.get(meta["url"], follow_redirects=True)
        if r.is_error:
            raise SystemExit(f"Downloading {name!r} failed with HTTP {r.status_code}.")

        # a login page instead of the file means the download link didn't authenticate
        if "html" in r.headers.get("content-type", "") and not name.endswith(".html"):
            raise SystemExit(
                f"Downloading {name!r} returned an HTML page "
                f"({r.url.copy_with(query=None)}) instead of the file."
            )

        folder.mkdir(parents=True, exist_ok=True)
        path = folder / name
        status = (
            "new"
            if not path.exists()
            else "unchanged"
            if path.read_bytes() == r.content
            else "updated"
        )
        path.write_bytes(r.content)
        print(f"   {status:<9} {path} ({len(r.content) // 1024} KB)")
        return status

    def _download_attachments(
        self,
        assignment: dict,
        folder: pathlib.Path,
    ) -> list[str]:
        # assignments embed attachments as file links in the description
        ids = re.findall(
            r'data-api-endpoint="[^"]*/files/(\d+)"',
            assignment.get("description") or "",
        )
        if not ids:
            print(f"   skipped   assignment {assignment['name']!r} (no attached files)")

        return [self._download_file(file_id, folder) for file_id in dict.fromkeys(ids)]


def _slug(name: str) -> str:
    return re.sub(r"\W+", "-", name.strip().lower()).strip("-")


def _format_assignment(a: dict) -> str:
    submission = a.get("submission") or {}
    state = submission.get("workflow_state", "-")
    attempt = submission.get("attempt") or "-"
    due = a["due_at"] or "no due date"
    types = ",".join(a["submission_types"])
    return (
        f"{a['id']:>8}  {due:<20}  {state:<12}  {attempt!s:>7}  {types:<14}  "
        f"{a['name']}"
    )


@app.command
def download(
    course_id: int,
    *,
    dest: pathlib.Path | None = None,
    auth: Auth = DEFAULT_AUTH,
) -> None:
    """Mirror a course's module files and assignment attachments locally.

    Files keep their Canvas names, in one subfolder per module and one per
    assignment (under assignments/) for assignments not in any module. Each file
    is reported as new, updated or unchanged relative to the previous run, so
    rerunning shows what changed on Canvas. Copy the files you need out of the
    mirror rather than editing them in place.

    Parameters
    ----------
    course_id
        Canvas course id, from the URL (e.g. /courses/22861/modules).
    dest
        Directory to mirror into. Defaults to ~/.cache/canvas/files/COURSE_ID.
    """
    dest = dest or CACHE_DIR / "files" / str(course_id)
    canvas = Canvas(auth)
    seen = set()
    statuses = Counter()

    for module in canvas.paginate(
        f"/courses/{course_id}/modules",
        **{"include[]": "items"},
    ):
        print(f"== module {module['name']!r}")
        folder = dest / _slug(module["name"])
        items = module.get("items") or canvas.paginate(
            f"/courses/{course_id}/modules/{module['id']}/items"
        )

        for item in items:
            if item["type"] == "File":
                statuses[canvas._download_file(str(item["content_id"]), folder)] += 1
            elif item["type"] == "Assignment":
                seen.add(item["content_id"])
                assignment = canvas.get(item["url"])
                statuses.update(canvas._download_attachments(assignment, folder))
            else:
                # pages, links, headers etc. have no file to save
                print(f"   skipped   {item['type']} {item['title']!r}")

    # many courses post homework only on the assignments page, not in modules
    for a in canvas.assignments(course_id):
        if a["id"] not in seen:
            print(f"== assignment {a['name']!r} (not in any module)")
            folder = dest / "assignments" / _slug(a["name"])
            statuses.update(canvas._download_attachments(a, folder))

    summary = ", ".join(f"{n} {s}" for s, n in statuses.items()) or "nothing"
    print(f"done: {sum(statuses.values())} files ({summary}) under {dest}")


@app.command
def assignments(course_id: int, *, auth: Auth = DEFAULT_AUTH) -> None:
    """List a course's assignments with your submission state and attempt count."""
    canvas = Canvas(auth)
    print(ASSIGNMENT_HEADER)
    for a in canvas.assignments(course_id):
        print(_format_assignment(a))


@app.command
def submit(
    course_id: int,
    assignment: str,
    file: pathlib.Path,
    *,
    name: str | None = None,
    auth: Auth = DEFAULT_AUTH,
) -> None:
    """Upload FILE and submit it to ASSIGNMENT. This creates a new attempt.

    Parameters
    ----------
    course_id
        Canvas course id, from the URL.
    assignment
        Assignment id (from `assignments`), or a name substring matching exactly
        one assignment.
    file
        File to upload and submit.
    name
        Filename to submit under. Defaults to the file's own name.
    """
    if not file.is_file():
        raise SystemExit(f"{file} does not exist or is not a file.")

    canvas = Canvas(auth)
    a = canvas._find_assignment(course_id, assignment)
    if "online_upload" not in a["submission_types"]:
        raise SystemExit(
            f"{a['name']!r} does not accept uploads (types: {a['submission_types']})."
        )
    previous = a.get("submission") or {}
    print(
        f"submitting to {a['id']} {a['name']!r} (due {a['due_at']}; currently "
        f"{previous.get('workflow_state', 'unsubmitted')}, "
        f"{previous.get('attempt') or 0} previous attempts)"
    )
    assignment_path = f"/courses/{course_id}/assignments/{a['id']}"

    # canvas uploads take three steps: request a slot, upload, then submit
    upload_name = name or file.name
    mime_type = mimetypes.guess_type(upload_name)[0] or "application/octet-stream"
    slot = canvas.post(
        f"{assignment_path}/submissions/self/files",
        data={
            "name": upload_name,
            "size": file.stat().st_size,
            "content_type": mime_type,
        },
    )

    # the upload host is external, so post without the canvas session
    upload = httpx.post(
        slot["upload_url"],
        data=slot["upload_params"],
        files={"file": (upload_name, file.read_bytes(), mime_type)},
        timeout=120,
    )
    meta = (
        canvas.get(upload.headers["location"]) if upload.is_redirect else _parse(upload)
    )
    print(f"uploaded file {meta['id']} ({meta['size'] // 1024} KB)")

    sub = canvas.post(
        f"{assignment_path}/submissions",
        data={
            "submission[submission_type]": "online_upload",
            "submission[file_ids][]": meta["id"],
        },
    )
    attachments = sub.get("attachments", [])
    if meta["id"] not in [x["id"] for x in attachments]:
        raise SystemExit(
            f"Canvas recorded attempt {sub['attempt']} without the uploaded file "
            f"{meta['id']}; check the submission page."
        )

    late = " LATE" if sub.get("late") else ""
    print(
        f"submitted attempt {sub['attempt']} at {sub['submitted_at']}{late}: "
        + ", ".join(x["display_name"] for x in attachments)
    )
    print(f"verify at {canvas.base}{assignment_path}/submissions/self")


if __name__ == "__main__":
    try:
        app()
    except httpx.TransportError as e:
        raise SystemExit(
            f"Could not reach Canvas ({type(e).__name__}: {e}). If running in a "
            "sandbox, rerun outside it or allow the host. This is not a cookie "
            "problem."
        ) from None
