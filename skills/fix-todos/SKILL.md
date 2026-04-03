---
name: fix-todos
description: "Use this skill when the user asks to fix, resolve, or address TODO comments in the codebase. Triggers include: 'fix todos', 'resolve claude todos', 'address the TODOs', 'implement the TODOs'. Searches for CLAUDE: prefixed comments and executes them."
---

# fix-todos

Find all comments with the `CLAUDE:` prefix in the codebase using `rg "CLAUDE:"`.
Read the relevant files and surrounding context to understand what is being asked.
If necessary, prompt the user for more information to solidify your understanding.

Once you have a good understanding of what is being asked, create a summary
table and prompt the user for confirmation that the todo items have been correctly
interpreted.

After confirmation, dispatch sub-agents to execute each task.
Dispatch agents in paralell when the tasks are unrelated.
For example, writing tests and writing documetation are separable tasks.
Use sequential dispatch when tasks touch the same files or have dependencies
(for example, implementing and then testing a feature).
If there are very few tasks or the tasks are simple, you may omit sub-agents
and execute everything in the main context.

After all tasks are complete, produce a summary table of how each task was implemented
and any important caveats.
