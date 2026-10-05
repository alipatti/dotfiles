---
name: review
description: "Load BEFORE doing any substantive review/feedback on code, writing, or other written work (e.g. a branch, proof, code implementation , paper, etc.). Triggers include 'review', 'critique', 'audit', 'check', 'look over', 'give feedback on', 'is this right/correct', 'check my proof', 'what's wrong with', 'is this ready'. Splits the review into tasks, runs each through Claude and Codex in parallel, and merges the findings."
---

# Parallel review

If `REVIEW_LEAF=1` is set or your prompt says you are a leaf reviewer,
stop reading and do the review yourself.

## 0. Decide whether to delegate

Small reviews do not need the script: a single function, a paragraph,
one part of a problem set.
Review those yourself.
Use the script for whole files, branches, papers, or problem sets.
If it is marginal, ask the user before launching.

## 1. Split

Skim the material yourself,
enough to write specific prompts and to check the reviewers' claims later.
Then split the review into 2-4 tasks, each covering one section
(file, module, problem, chapter) or one perspective:

- **Code:** architecture and abstractions, correctness,
  idiomatic code and library choice, research validity.
- **Math:** by problem (group short ones), or by perspective:
  correctness of steps and answers, rigor and gaps,
  notation and exposition.
- **Prose:** argument and structure, clarity, style.

## 2. Write prompts

Write one file per task to `$DIR/prompts/<task>.md`,
where `$DIR` is a fresh absolute directory in your scratchpad or temp dir.
Each prompt says what the material is, where it lives, the task's scope,
and what the other tasks cover.
The script prepends `preamble.md`
(leaf-reviewer rules, how to verify, error/gap/presentation classification,
report format), so leave those out.

## 3. Run

```bash
~/.dotfiles/skills/review/review.py "$DIR" -C /path/to/repo -f psets/3.typ
```

- Run it outside the sandbox (both CLIs need network);
  in Claude Code, also with `run_in_background`.
- `-f` inlines files, line-numbered, into every prompt.
  Use it when the material is small
  (a few thousand lines); omit for large repos.
  Prefer source (`.typ`, `.tex`, `.md`) over PDFs when both exist.
  Short PDFs (e.g. problem set statements) are fine to pass with `-f`.
  PDFs go through `pdf2md` (cached),
  whose first run can take minutes on long PDFs.
- Web search and fetching are on by default.
  Pass `--no-web` for untrusted material
  (e.g. a stranger's PR),
  since injected instructions could leak content through queries or URLs.
- `--reviewers codex` runs only one CLI.
- It prints one line per review as it finishes,
  then `all done: N ok, M failed`.
  Reviews land in `$DIR/reviews/<task>.<reviewer>.md`;
  transcripts in `$DIR/logs/` (for failures; don't read whole).

## 4. Merge

Wait for `all done`.
Do not report reviews that have not arrived.
For each task, merge the reports into: findings both reviewers raised
(higher confidence),
findings only one raised, and disagreements, with each side's reasoning.

Before presenting a severe or surprising claim,
check it yourself against the source
(read the cited lines, run a small check),
and say which claims you checked.
Rank findings by importance across tasks, not per reviewer.

Reviewers that find no major problems return line edits
(`path:line`: `old` -> `new`)
for style, idioms, grammar, and typos, and small refactors
(extracting a helper, consolidating duplicated logic).
Apply obvious, minimally intrusive ones yourself
(typos, grammar, clear idiom fixes,
local refactors that don't change behavior or interfaces)
and report them only as a brief summary of what changed, not edit by edit.
List the rest (judgment calls, larger refactors,
or edits the reviewers disagree on) after the findings,
grouped by file in line order.
Drop ones you disagree with.
