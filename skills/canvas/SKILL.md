---
name: canvas
description: "Use this skill when downloading files, listing modules, submitting assignments, or otherwise interacting with Canvas LMS (princeton.instructure.com / canvas.princeton.edu, or other *.instructure.com sites)."
---

# Canvas Skill

Use the premade CLI `scripts/canvas.py` (relative to this skill):

```bash
uv run scripts/canvas.py download COURSE_ID [--dest DIR] [--cookie VALUE]
uv run scripts/canvas.py submit COURSE_ID ASSIGNMENT FILE [--name UPLOAD_NAME]
```

- The course id is in the Canvas URL (e.g. `/courses/22861/modules`).
- Authentication uses the `canvas_session` cookie
  (Princeton disables API token generation).
  The script validates it against the API and caches a working cookie in
  `~/.cache/canvas/`, so later runs need no flags. When there is no valid
  cached cookie, ask the user to paste a fresh one
  (Safari Web Inspector Cmd+Opt+I > Storage > Cookies > `canvas_session`)
  and pass it with `--cookie`.
- `download` grabs module items of type File and Assignment
  (assignment attachments are parsed out of the description HTML).
- `submit` takes an assignment id or a name substring (must match exactly
  one) and submits FILE as an `online_upload`. Cookie-authed POSTs need the
  `X-CSRF-Token` header (URL-decoded `_csrf_token` cookie, set by any GET);
  `_session` handles this. Submitting creates a new attempt and cannot be
  undone, so confirm with the user before running.
  After a successful submit, open the submission page in the browser so the
  user can verify it:
  `open "https://princeton.instructure.com/courses/COURSE_ID/assignments/ASSIGNMENT_ID/submissions/self"`
  (needs to run outside the sandbox).
- The sandbox network allowlist may not include instructure.com, and the
  cookie cache write needs `~/.cache/canvas/`; the script may need to run
  outside the sandbox.
- Run with `--help` for all options; for other Canvas API needs, add a
  subcommand reusing the `_session`/`_api` helpers
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
