# Agent Instructions

- Keep replies concise.
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
- Do not push branches created in worktrees (`.claude/worktrees/`).

## Coding

- Write comments in lowercase.
- Load the language-appropriate skill
  before the first edit to a file of that type
  (python, typst, etc.) if such a skill exists.
- Search documentation when encountering unfamiliar libraries or APIs.
- Write markdown with semantic line breaks
  (one sentence or clause per line).
  Edited `.md` files are reformatted with `rumdl fmt`,
  so re-read a file before editing it again.

## Shell tools

- Use `rg` instead of `grep -r` and `fd` instead of `find`.
  Both respect `.gitignore` by default and are faster.
- Use `rga` (ripgrep-all) to search inside PDFs and other documents
  instead of looping over `pdftotext`.
- Use `trash` instead of `rm` to delete potentially important files.
  Use `rm` If the file is git tracked or a temp file.

## Editor

The user often has nvim open in another kitty window in the same tab.
Load the nvim-peer skill when they say "this" or "here",
or when you want to show them code in their editor.
