#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.9"
# dependencies = [
#     "browser-cookie3>=0.20.1",
#     "cyclopts>=3",
#     "requests",
# ]
# ///
"""Download all file items from a Canvas course's modules.

Authenticates with the browser's canvas_session cookie, pulled from Safari
automatically (needs Full Disk Access) or passed explicitly with --cookie.

    uv run canvas_download.py 22861
    uv run canvas_download.py 22861 --dest ~/classes/econ-501
    uv run canvas_download.py 22861 --cookie <pasted canvas_session value>
"""
import json
import pathlib
import re
import sys
from typing import Optional

import browser_cookie3
import requests
from cyclopts import App

app = App(help="Download all File items from a Canvas course's modules.")


def _session(base: str, cookie: Optional[str]) -> requests.Session:
    s = requests.Session()
    if cookie:
        s.cookies.update({"canvas_session": cookie})
        return s
    domain = base.split("//", 1)[-1]
    try:
        jar = browser_cookie3.safari(domain_name=domain)
    except (browser_cookie3.BrowserCookieError, PermissionError) as e:
        sys.exit(
            f"Could not read Safari cookies: {e}\n"
            "On macOS your terminal likely needs Full Disk Access "
            "(System Settings > Privacy & Security).\n"
            "Alternatively pass --cookie with the canvas_session value from "
            "Safari Web Inspector (Cmd+Opt+I) > Storage > Cookies."
        )
    if not any(c.name == "canvas_session" for c in jar):
        sys.exit(f"No canvas_session cookie found for {domain}; log in first "
                 "or pass --cookie.")
    s.cookies.update(jar)
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
        canvas_session cookie value. Defaults to reading it from Safari.
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
            if item["type"] != "File":
                continue
            meta = _api(s, base, item["url"].removeprefix(base))[0]
            folder.mkdir(parents=True, exist_ok=True)
            path = folder / meta["display_name"]
            r = s.get(meta["url"], allow_redirects=True)
            r.raise_for_status()
            path.write_bytes(r.content)
            print(f"   saved {path} ({len(r.content) // 1024} KB)")


if __name__ == "__main__":
    app()
