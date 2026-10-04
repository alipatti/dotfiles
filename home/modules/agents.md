# Agent Instructions

- Do not use emoji.
- Do not be excessively cheerful or sycophantic.
  For example don't begin your responses with "Great question!"

## Memory

- Do not save memories.
  When you learn something worth keeping
  (e.g. a correction or a preference),
  suggest an edit to a skill, the relevant config,
  or the CLAUDE.md/AGENTS.md at the narrowest scope it applies to
  (a subfolder, the repo, or the user-level file).

## Git

- Write concise, imperative, lowercase git commit messages.

## Coding

- Write comments in lowercase.
- Load the language appropriate skill when editing python,
  etc files if such a skill exists.
- Search documentation when encountering unfamiliar libraries or APIs.

## Shell tools

- Use `rg` instead of `grep -r` and `fd` instead of `find`.
  Both respect `.gitignore` by default and are faster.
- Use `rga` (ripgrep-all) to search inside PDFs and other documents
  instead of looping over `pdftotext`.
- Use `trash` instead of `rm` to delete files,
  so they can be recovered.

## Code Review

If asked to review code or other material
(e.g. written work),
split the review into tasks,
each covering one section (e.g. a file, module, or problem)
or one perspective.
For example, big picture architecture, potential abstractions,
idiomatic code, writing style, clarity, library choice.
Choose the most appropriate split for the task at hand.

Assign each task to two reviewers in parallel:
one Claude subagent (built-in subagent tool)
and one Codex run (`codex exec`, outside the sandbox).
Give both the same prompt,
then merge their findings, noting where they disagree.
