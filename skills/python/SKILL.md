---
name: python
description: "Load BEFORE writing, editing, or reviewing any Python code: .py files, pyproject.toml, uv commands, or inline scripts. Contains style and best practices, and points to library-specific skills (polars, plotnine) that must also be loaded."
---

# Python

## Style

Write pythonic code.
In particular:

- Use list/generator comprehensions, `pathlib`, f-strings, `itertools`,
  `functools`, `collections`, and other tools from the standard library.
- Use the ternary conditional (`y if x else z`) for simple conditionals.
- Use short-circuiting: `x or default` and `condition and value`.

In addition:

- Extract a helper when logic repeats multiple times,
  or a name would clarify intent that inline code doesn't convey.
- Prefer consolidation.
  If there are several similar functions,
  think about how to abstract their shared functionality.
  Don't be afraid to refactor.
- Use lowercase for comments and title case for docstrings
  and error messages.
  Include comments iff functionality is not obvious.
  Prefer extracting descriptively named constants
  (if short and used only once)
  or helper functions (if long or used multiple times) to extensive
  commentary.
- Don't add defensive error handling
  (`try`/`except`, input validation) for cases that can't occur.
  Only guard system boundaries: user input, network calls, file I/O.

### Whitespace

- Use ample whitespace.
- Always put a blank line before and after an `if` block
  (including its `elif`/`else` blocks),
  unless it starts or ends the enclosing block
  (for example, the first line of a function).
- Group the rest of the code into paragraphs separated by blank lines.
  Start a paragraph with a descriptive comment only
  if its purpose isn't obvious from the code itself.
- In function signatures and calls with more than three arguments,
  put each argument on its own line and end with a trailing comma,
  so `ruff format` keeps them split.
  For calls with three or fewer arguments,
  use your discretion and split when the code becomes difficult to read.

  ```python
  def around_steady_state(
      n_points: int = 6,
      r: float = 0.05,
  ) -> tuple[np.ndarray, np.ndarray]:
      result = subprocess.run(
          ["solver", "--points", str(n_points)],
          capture_output=True,
          text=True,
          check=False,
      )

      if result.returncode:
          sys.exit(f"Solver failed:\n{result.stderr}")

      grid = np.linspace(-r, r, n_points)
      return grid, np.interp(grid, *parse(result.stdout))
  ```

## Tooling

- Manage dependencies with `uv` and `pyproject.toml`
  (`uv add`, `uv run`), not pip/poetry/conda.
- Format with `uvx ruff format`, lint with `uvx ruff check --fix`,
  type-check with `uvx ty check`.
  Run all three after any substantive change — don't wait to be asked.
- Define CLI entrypoints
  as `[project.scripts]` in `pyproject.toml` pointing at a cyclopts `App`
  instance, e.g. `mytool = "mytool.cli:app"`.

## Documentation

- Parameter and function names should be self-documentating
  and one should ideally not need the docstring to figure out what code
  does.
- Default to short, descriptive docstrings without Parameters, Examples,
  etc.
  A single line is often sufficient.
- Reserve full Numpydoc-style docstrings
  (Parameters, Returns, Raises, Examples, as applicable)
  for public APIs of libraries meant to be used by others,
  or functions whose behavior isn't clear from the signature
  and a short summary.
  When examples are included, they should be complete and testable.

## Types

Use type hints for all function signatures.
In particular:

- Prefer modern syntax if the python version supports it:
  `str | None` not `Optional[str]`, `list[int]` not `List[int]`,
  generics as `def first[T](items: list[T]) -> T`.
- Use string literals `Literal["option1", "option2"]`
  for function arguments that can take multiple values.
- Extract type aliases when types are complex and/or appear in many places.
  For example `type OutputType = Literal["json", "txt", "csv"]`,
  `type InnerFunction = Callable[[pl.DataFrame, int], float]`.
- Don't use strings for type hints (`"MyClass"`).
  Use `Self` for the enclosing class,
  or reorder definitions / use `from __future__ import annotations`
  if needed.
- Use `typing` exports to express intent precisely:
  `Self` for methods returning their own class,
  `@override` on overridden methods, `Final`/`ClassVar` for constants,
  `Never` for functions that never return, `TypeIs` for type guards.
- Import abstract containers and callables
  (`Iterable`, `Sequence`, `Callable`, …)
  from `collections.abc` rather than `typing`.

## Testing

- Use `pytest`.
- Use plain `assert` statements rather than `unittest`-style assertion
  methods.
- Each test should test one specific behavior.
- Use descriptive test names and include a short,
  imperative docstring describing the intended functionality.
- Use test parameterization for similar tests.
- Use fixtures for shared setup.
  Built-in fixtures like `tmp_path: Path`
  and `monkeypatch: pytest.MonkeyPatch` are often useful.
- Don't mock internal modules.
  Only mock true external boundaries.
- Rerun the appropriate tests after substantive changes.

## Libraries

Use the libraries listed below when appropriate.
Avoid using the libraries in the "Not" column.
Ask before installing things not on this list.

Some of these libraries have their own skills.
Load a library's skill before writing any code that uses it,
even when the library is incidental to the task
(e.g. a polars frame returned by a simulation).
When there's no skill, refer to the sections below.

When unsure about an API, check the installed version's source
(docstrings and signatures under
`.venv/lib/python*/site-packages/<package>`) and the linked the web
documentation.

| Purpose         | Use                     | Not                     | Documentation                                                    |
| --------------- | ----------------------- | ----------------------- | ---------------------------------------------------------------- |
| Tabular data    | polars                  | pandas                  | Load skill.                                                      |
| CLI             | cyclopts                | argparse, click, typer  | <https://cyclopts.readthedocs.io/en/stable/getting_started.html> |
| Figures         | plotnine                | matplotlib, seaborn     | Load skill.                                                      |
| HTTP            | httpx (sync by default) | requests, urllib        | <https://www.python-httpx.org/quickstart/>                       |
| HTML parsing    | parsel                  | BeautifulSoup, lxml     | <https://parsel.readthedocs.io/en/latest/usage.html>             |
| Structured data | pydantic or dataclasses | TypedDict, manual dicts | <https://docs.pydantic.dev/latest/>                              |
| Logging         | loguru                  | stdlib logging          | <https://loguru.readthedocs.io/en/stable/overview.html>          |
| Testing         | pytest                  | unittest                | <https://docs.pytest.org/en/stable/>                             |

### httpx

Use the sync by default.
Use a `Client` context manager for anything beyond a single one-off call.
Call `raise_for_status()` rather than checking status codes manually.

### parsel

Prefer CSS selectors over XPath unless XPath is meaningfully simpler
for the case (e.g. text-content ancestor lookups).

### pydantic

Reach for `BaseModel` any time data crosses a boundary
(API responses, config, CLI-adjacent structured input)
instead of raw dicts or dataclasses.

### alipatti

The user's personal helper package
(private repo <https://github.com/alipatti/alipatti.py>),
with optional extras per submodule (e.g. `alipatti[plot]`).
Import it as `import alipatti as ap` and reference submodules as `ap.plot`,
`ap.cache`, etc.
Before writing a generic helper, check whether the package already has one,
and import it rather than copying its code into the project.
If you have an idea for a new helper or for changes to an existing helper,
suggest it to the user.
