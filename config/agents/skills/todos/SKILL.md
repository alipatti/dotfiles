---
name: todos
description: fix the CLAUDE notes in the repo
allowed-tools: Bash(rg:*)
disable-model-invocation: true
---

Fix these todo notes:

!`rg --line-number --heading --context 5 --max-columns 200 --sort path -e "\b($(echo "$ARGUMENTS" | sed -E 's/^ *$/CLAUDE/; s/ +/|/g')):" . || echo "no todo items"`
