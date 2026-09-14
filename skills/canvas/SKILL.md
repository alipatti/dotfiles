---
name: canvas
description: "Use this skill when downloading files, listing modules, or otherwise interacting with Canvas LMS (princeton.instructure.com / canvas.princeton.edu, or other *.instructure.com sites)."
---

# Canvas Skill

Use the premade script `scripts/canvas_download.py`
(relative to this skill) to download all files from a course's modules:

```bash
uv run scripts/canvas_download.py COURSE_ID [--dest DIR] [--cookie VALUE]
```

- The course id is in the Canvas URL (e.g. `/courses/22861/modules`).
- Authentication uses the `canvas_session` cookie
  (Princeton disables API token generation).
  The script validates it against the API and caches a working cookie in
  `~/.cache/canvas/`, so later runs need no flags. When there is no valid
  cached cookie, ask the user to paste a fresh one
  (Safari Web Inspector Cmd+Opt+I > Storage > Cookies > `canvas_session`)
  and pass it with `--cookie`.
- Module items of type File and Assignment are both downloaded
  (assignment attachments are parsed out of the description HTML).
- The sandbox network allowlist may not include instructure.com; the script may
  need to run outside the sandbox.
- Run with `--help` for all options; for other Canvas API needs,
  adapt the script's `_api` helper
  (cookie auth works on all `/api/v1/` endpoints;
  strip the `while(1);` response prefix, paginate via the `Link` header).
  Do the hacking manually first, and if it works,
  ask the user if they'd like to update this skill.

## Conventions

- Save files as
  `handouts/{lecture-notes, slides, etc.}/YYYY-MM-DD-topic-slug.pdf` (dates from
  the course meeting schedule, slugs from lecture titles), matching the layout
  of the other course directories under `~/Documents/education/classes/`.
  If in doubt, ask the user for lecture dates.
- Verify downloads with `file *.pdf` —
  an expired cookie yields HTML login pages, not PDFs.
