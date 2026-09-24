#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.9"
# dependencies = [
#     "cyclopts>=3",
#     "requests",
# ]
# ///
"""Canvas LMS CLI: download course files, submit assignments.

Authenticates with the canvas_session cookie: pass it once with --cookie
(from Safari Web Inspector Cmd+Opt+I > Storage > Cookies) and it is cached
in ~/.cache/canvas/ until it expires.

    uv run canvas.py download 22861
    uv run canvas.py download 22861 --dest ~/classes/econ-501
    uv run canvas.py submit 22864 "Problem Set 1" solutions.pdf
    uv run canvas.py submit 22864 200543 solutions.pdf --name pattison-ps1.pdf
"""

import json
import mimetypes
import pathlib
import re
from urllib.parse import unquote

import requests
from cyclopts import App

app = App(help="Canvas LMS CLI: download course files, submit assignments.")

CACHE_DIR = pathlib.Path.home() / ".cache" / "canvas"
DEFAULT_BASE = "https://princeton.instructure.com"


def _session(base: str, cookie: str | None) -> requests.Session:
    domain = base.split("//", 1)[-1]
    cache = CACHE_DIR / f"canvas_session-{domain}"
    if not cookie:
        if not cache.is_file():
            raise SystemExit(
                f"No cached cookie for {domain}. Pass --cookie with the "
                "canvas_session value from Safari Web Inspector "
                "(Cmd+Opt+I) > Storage > Cookies."
            )
        cookie = cache.read_text().strip()
    s = requests.Session()
    s.cookies.update({"canvas_session": cookie})
    if not s.get(f"{base}/api/v1/users/self").ok:
        cache.unlink(missing_ok=True)
        raise SystemExit(
            "Cookie is invalid or expired; pass a fresh one with --cookie."
        )
    # skip the rewrite when unchanged so sandboxed runs work with a cached cookie
    if not (cache.is_file() and cache.read_text().strip() == cookie):
        CACHE_DIR.mkdir(parents=True, exist_ok=True)
        cache.write_text(cookie)
        cache.chmod(0o600)
    # mutating requests need the csrf token that the GET above set
    s.headers["X-CSRF-Token"] = unquote(s.cookies.get("_csrf_token", ""))
    return s


def _api(s: requests.Session, base: str, path: str, **params) -> list:
    out = []
    url = f"{base}{path}"
    params = {"per_page": 100, **params}
    while url:
        r = s.get(url, params=params)
        params = {}
        r.raise_for_status()
        data = json.loads(r.text.removeprefix("while(1);"))
        out.extend(data if isinstance(data, list) else [data])
        url = r.links.get("next", {}).get("url")
    return out


def _json(r: requests.Response) -> dict:
    r.raise_for_status()
    return json.loads(r.text.removeprefix("while(1);"))


def _save_file(
    s: requests.Session, base: str, file_id: str, folder: pathlib.Path
) -> None:
    meta = _api(s, base, f"/api/v1/files/{file_id}")[0]
    folder.mkdir(parents=True, exist_ok=True)
    path = folder / meta["display_name"]
    r = s.get(meta["url"], allow_redirects=True)
    r.raise_for_status()
    path.write_bytes(r.content)
    print(f"   saved {path} ({len(r.content) // 1024} KB)")


@app.command
def download(
    course_id: int,
    *,
    dest: pathlib.Path = pathlib.Path("."),
    cookie: str | None = None,
    base: str = DEFAULT_BASE,
):
    """Download all File items from a course's modules.

    Parameters
    ----------
    course_id
        Canvas course id, from the URL (e.g. /courses/22861/modules).
    dest
        Directory to download into; one subfolder per module.
    cookie
        canvas_session cookie value. Defaults to the cached one.
    base
        Canvas base URL.
    """
    s = _session(base, cookie)
    for mod in _api(
        s, base, f"/api/v1/courses/{course_id}/modules", **{"include[]": "items"}
    ):
        folder = dest / re.sub(r"\W+", "-", mod["name"].strip().lower()).strip("-")
        items = mod.get("items") or _api(
            s, base, f"/api/v1/courses/{course_id}/modules/{mod['id']}/items"
        )
        print(f"== {mod['name']}")
        for item in items:
            if item["type"] == "File":
                _save_file(s, base, str(item["content_id"]), folder)
            elif item["type"] == "Assignment":
                # assignments embed attachments as file links in the description
                a = _api(s, base, item["url"].removeprefix(base))[0]
                ids = re.findall(
                    r'data-api-endpoint="[^"]*/files/(\d+)"', a.get("description") or ""
                )
                if not ids:
                    print(f"   skipped {item['title']} (no attached files)")
                for fid in ids:
                    _save_file(s, base, fid, folder)


def _find_assignment(
    s: requests.Session, base: str, course: str, assignment: str
) -> dict:
    if assignment.isdigit():
        return _json(s.get(f"{base}/api/v1/courses/{course}/assignments/{assignment}"))
    matches = _json(
        s.get(
            f"{base}/api/v1/courses/{course}/assignments",
            params={"search_term": assignment, "per_page": 100},
        )
    )
    if len(matches) != 1:
        names = ", ".join(f"{a['id']} {a['name']!r}" for a in matches)
        raise SystemExit(
            f"Expected exactly one assignment matching "
            f"{assignment!r}, got: {names or 'none'}"
        )
    return matches[0]


@app.command
def submit(
    course_id: str,
    assignment: str,
    file: pathlib.Path,
    *,
    name: str | None = None,
    cookie: str | None = None,
    base: str = DEFAULT_BASE,
) -> None:
    """Upload FILE and submit it to ASSIGNMENT (id or name substring).

    Parameters
    ----------
    course_id
        Canvas course id, from the URL.
    assignment
        Assignment id, or a name substring matching exactly one assignment.
    file
        File to upload and submit.
    name
        Filename to submit under. Defaults to the file's own name.
    cookie
        canvas_session cookie value. Defaults to the cached one.
    base
        Canvas base URL.
    """
    s = _session(base, cookie)
    a = _find_assignment(s, base, course_id, assignment)
    if "online_upload" not in a["submission_types"]:
        raise SystemExit(
            f"{a['name']!r} does not accept uploads (types: {a['submission_types']})"
        )
    print(f"submitting to {a['id']} {a['name']!r} (due {a['due_at']})")

    upload_name = name or file.name
    slot = _json(
        s.post(
            f"{base}/api/v1/courses/{course_id}/assignments/{a['id']}"
            "/submissions/self/files",
            data={
                "name": upload_name,
                "size": file.stat().st_size,
                "content_type": mimetypes.guess_type(upload_name)[0]
                or "application/octet-stream",
            },
        )
    )
    up = requests.post(
        slot["upload_url"],
        data=slot["upload_params"],
        files={"file": (upload_name, file.read_bytes())},
        allow_redirects=False,
    )
    if up.status_code in (301, 302, 303):
        meta = _json(s.get(up.headers["Location"]))
    else:
        meta = _json(up)
    print(f"uploaded file {meta['id']} ({meta['size'] // 1024} KB)")

    sub = _json(
        s.post(
            f"{base}/api/v1/courses/{course_id}/assignments/{a['id']}/submissions",
            data={
                "submission[submission_type]": "online_upload",
                "submission[file_ids][]": meta["id"],
            },
        )
    )
    late = " LATE" if sub.get("late") else ""
    print(
        f"submitted attempt {sub['attempt']} at {sub['submitted_at']}"
        f"{late}: " + ", ".join(x["display_name"] for x in sub.get("attachments", []))
    )


if __name__ == "__main__":
    app()
