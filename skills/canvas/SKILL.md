---
name: canvas
description: "Use this skill when downloading files, listing modules, submitting assignments, or otherwise interacting with Canvas LMS (princeton.instructure.com / canvas.princeton.edu, or other *.instructure.com sites)."
---

# Canvas Skill

Interact with Canvas only through the CLI at `scripts/canvas.py`
(relative to this skill).
Never write ad-hoc Python or call the Canvas API yourself.
Run `uv run scripts/canvas.py --help`
(and `COMMAND --help`)
for usage; its error messages say what went wrong,
so read them before guessing.
If the CLI can't do something, propose a new subcommand to the user.

```bash
# list your current courses with their ids
uv run scripts/canvas.py courses

# list course 22872's assignments with their ids, due dates and submission state
uv run scripts/canvas.py assignments 22872

# preview, then submit, submission.pdf to assignment 205810 (id from the list above)
uv run scripts/canvas.py submit 22872 205810 submission.pdf --dry-run
uv run scripts/canvas.py submit 22872 205810 submission.pdf

# mirror module files and assignment attachments into ~/.cache/canvas/files/22872/
uv run scripts/canvas.py download 22872
```

- The course id should be in the course repo's CLAUDE.md.
  If it isn't, find it with `courses` and add it there.
- Submitting creates a new attempt and cannot be undone.
  Run with `--dry-run` and confirm its output with the user first,
  then `open` the "verify at" URL it prints (outside the sandbox).
- `download` only mirrors files under their Canvas names.
  Then copy (don't move or hardlink) each `new`
  or `updated` file it reports into the course repo,
  renamed per the conventions below.

## Conventions

- Save files as `handouts/{lecture-notes, slides, etc.}/N-topic-slug.pdf`
  (N is the lecture number, slugs from lecture titles,
  e.g. `handouts/lecture-notes/2-lln-clt-delta-method.pdf`),
  matching the layout of the other course directories under
  `~/Documents/education/classes/`.
- Problem sets go in `psets/N/`:
  the assignment as `problems.pdf` and instructor solutions
  as `solutions.pdf` (plus any starter code).
  The user's own writeup is `submission.*` (e.g. `submission.typ`).
