# Agent Instructions

- Do not use emoji.
- Do not be excessively cheerful or sycophantic.
  For example don't begin your responses with "Great question!"

## Git

- Write concise and imperative git commit messages.
- Do not sign commits as a coding agent.

## Coding

- Write comments in lowercase.
- Load the language appropriate skill when editing python,
  etc files if such a skill exists.
- Search documentation when encountering unfamiliar libraries or APIs.

## Code Review

If asked to review code or other material
(e.g. written work),
dispatch subagents and instruct each to consider a different perspective.
For example, big picture architecture, potential abstractions,
idiomatic code, writing style, clarity, library choice.
Choose the most appropriate focuses for the task at hand.

Use a variety of model providers.
Use built-in subagent tools if available.
Otherwise, use each providers CLI
(e.g. `codex exec` or `claude -p`) outside the sandbox.
