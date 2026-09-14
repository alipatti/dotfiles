#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.9"
# dependencies = [
#     "cyclopts>=3",
#     "requests",
# ]
# ///
"""Download all file items from a Canvas course's modules.

Authenticates with the canvas_session cookie: pass it once with --cookie
(from Safari Web Inspector Cmd+Opt+I > Storage > Cookies) and it is cached
in ~/.cache/canvas/ until it expires.

    uv run canvas_download.py 22861
    uv run canvas_download.py 22861 --dest ~/classes/econ-501
    uv run canvas_download.py 22861 --cookie <pasted canvas_session value>
"""
import json
import pathlib
import re
from typing import Optional

import requests
from cyclopts import App

app = App(help="Download all File items from a Canvas course's modules.")

CACHE_DIR = pathlib.Path.home() / ".cache" / "canvas"


def _session(base: str, cookie: Optional[str]) -> requests.Session:
    domain = base.split("//", 1)[-1]
    cache = CACHE_DIR / f"canvas_session-{domain}"
    if not cookie:
        if not cache.is_file():
            raise SystemExit(
                f"No cached cookie for {domain}. Pass --cookie with the "
                "canvas_session value from Safari Web Inspector "
                "(Cmd+Opt+I) > Storage > Cookies.")
        cookie = cache.read_text().strip()
    s = requests.Session()
    s.cookies.update({"canvas_session": cookie})
    if not s.get(f"{base}/api/v1/users/self").ok:
        cache.unlink(missing_ok=True)
        raise SystemExit("Cookie is invalid or expired; pass a fresh one "
                         "with --cookie.")
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    cache.write_text(cookie)
    cache.chmod(0o600)
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


def _save_file(s: requests.Session, base: str, file_id: str,
               folder: pathlib.Path) -> None:
    meta = _api(s, base, f"/api/v1/files/{file_id}")[0]
    folder.mkdir(parents=True, exist_ok=True)
    path = folder / meta["display_name"]
    r = s.get(meta["url"], allow_redirects=True)
    r.raise_for_status()
    path.write_bytes(r.content)
    print(f"   saved {path} ({len(r.content) // 1024} KB)")


@app.default
def main(
    course_id: int,
    *,
    dest: pathlib.Path = pathlib.Path("."),
    cookie: Optional[str] = None,
    base: str = "https://princeton.instructure.com",
):
    """
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
    for mod in _api(s, base, f"/api/v1/courses/{course_id}/modules",
                    **{"include[]": "items"}):
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
                ids = re.findall(r'data-api-endpoint="[^"]*/files/(\d+)"',
                                 a.get("description") or "")
                if not ids:
                    print(f"   skipped {item['title']} (no attached files)")
                for fid in ids:
                    _save_file(s, base, fid, folder)


if __name__ == "__main__":
    app()
