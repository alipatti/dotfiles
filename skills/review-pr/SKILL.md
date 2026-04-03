---
name: pr-review
description: "Use this skill when the user asks to review a pull request, check a PR, audit a diff, or do a code review. Triggers include: 'review this PR', 'check the diff', 'look at my changes', 'is this PR ready to merge'. Requires being run inside a git repository with a configured GitHub remote."
context: fork
---

# PR Review

Before you begin, gather context on the branch.
Check the diff with `main`/`master`.
If a PR exists, read its title, description, and any review comments.
The implementation should match what the PR claims to do.
Flag any mismatch and any unresolved comments.

```fish
# Get the diff
git diff main 2>/dev/null || git diff master

# Get PR metadata
gh pr view --json title,body,comments
```

Look for a contributing guide in the repo root:

```fish
ls CONTRIBUTING.md CONTRIBUTING.rst 2>/dev/null || fd -d 2 -i contributing
```

In addition to the checks listed below, ensure that any project-specific requirements or style guidelines are followed.

Then, run the following checks in order and produce a report whose structure is described at the end of this document.

## Checklist

### Tests, lints, type checks, formatting

If there is a github PR for this branch, check the status of its CI pipeline:

```fish
gh pr checks --json name,state,description,link,completedAt
```

If CI is not available, check the contribution guidelines for reference to any automated checking (for example, a list of linters/formatters or a script that will run all automated checks).

If no guideance is provided and this is a Python repository, use the following tools:

```fish
ruff format --check
ruff check
pyright
pytest
```

Flag any failures.

### Test coverage

For every new feature, verify there is a corresponding test.
Flag untested logic paths, especially branches and error cases.

### Documentation

Verify that every new public feature is documented according to the contribution guidelines.

If there are no guidelines, default to the Numpy docstring style (for Python) and ensure that all parameters/return types/exceptions are provided.

Ensure that nontrivial functions have examples showing the standard use cases.

Ensure that functions raise helpful and actionable errors.

Flag missing or stale documentation.

### Breaking changes

Check for:
- Removed or renamed public symbols (e.g. functions, classes, types, constants, modules)
- Changed function signatures (parameter names, types, order, defaults)
- Changed return types or error cases

If the project uses semver, flag whether a major or minor bump is warranted.

### Design and complexity

- Is the abstraction appropriate?
- Prefer functions to classes.
- Is duplicated logic extracted, or is there copy-paste that should be shared?
- Could any part of the code be replaced by something already in the stdlib, the existing codebase, or a well-regarded package?

### Maintainability

- Are names clear and consistent with surrounding code?
- Are magic numbers/strings extracted into named constants?
- Is the control flow easy to follow, or is there deep nesting that could be flattened?
- Are there places where code could be made more pythonic (for example, introducing list comprehensions, classes from itertools, collections, or replacing complex logic with features from the standard library).
- In Python code, do all paths use `pathlib.Path`?
- For each new dependency, could it be replaced with the standard library or an existing dep?
- Ensure logging is done with the logging module rather than print statements.

### Security

- Ensure there are no hardcoded secrets, tokens, or credentials.

### Performance

- Are there Python implementations of features that could be replaced with native Polars vectorizations?
- Are there loops in Python that could be replaced with native-C functions from the standard library?

## Output format

Produce a report with this structure:

```markdown
## PR Review: <title>

### Summary
<2-3 sentence overall assessment: ready / needs changes / blocked>

### Required changes
<Bulleted list of blockers — must be fixed before merge>

### Suggestions
<Bulleted list of non-blocking improvements>
```

Be concise in your review and assume that the user is a skilled programmer.
If they want more detail about a particular critique, they will ask.
