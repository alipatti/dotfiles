---
name: todos
description: fix the CLAUDE notes in the repo
allowed-tools: Bash(rg:*)
disable-model-invocation: true
---

Fix these todo notes:

!`rg --line-number --heading --context 5 --max-columns 200 --sort path -e "\b($(echo "$ARGUMENTS" | sed -E 's/^ *$/CLAUDE/; s/ +/|/g')):" . || echo "no todo items"`

## Ambiguity

If a request is ambiguous, request clarification rather than infer intent.

## Reporting

Reply in a few lines covering only:

- todos you skipped or couldn't resolve, and why
- any outstanding tasks

If none apply, reply with the single word "Done."
Do _not_ summarize the changes you made.
Those are available to the user in the diff.
