---
name: python
description: "Use this skill whenever you use or consider using python. Contains style/best practices"
---

## Style

Write pythonic code. In particular:

- Use list/generator comprehensions, `pathlib`, f-strings, `itertools`, `functools`, `collections`, and other tools from the standard library.
- Use the ternary conditional (`y if x else z`) for simple conditionals.
- Use short-circuiting: `x or default` and `condition and value`.

In addition:

- Extract a helper when logic repeats multiple times, or a name would clarify intent that inline code doesn't convey.
- Use lowercase for comments. Include comments iff functionality is not obvious. Prefer extracting descriptively named helper functions to extensive comments.
- Use ample whitespace. For example, include a blank line between `if` blocks and surrounding code. Group blocks of code into paragraphs separated by whitespace. Start each paragraph with a descriptive comment.
- Don't add defensive error handling (`try`/`except`, input validation) for cases that can't occur. Only guard system boundaries: user input, network calls, file I/O.

## Tooling

- Manage dependencies with `uv` and `pyproject.toml` (`uv add`, `uv run`), not pip/poetry/conda.
- Format with `uvx ruff format`, lint with `uvx ruff check --fix`, type-check with `uvx ty check`. Run all three after any substantive change — don't wait to be asked.

## Documentation

- Parameter and function names should be self-documentating and one should ideally not need the docstring to figure out what code does.
- Public functions/classes should have full Numpydoc-style docstrings (Parameters, Returns, Raises, Examples, as applicable). Nontrivial functions should have complete, testable examples.
- Internal functions should have short, descriptive docstrings. A single line is often sufficient.

## Types

Use type hints for all function signatures. In particular:

- Prefer modern syntax if the python version supports it: `str | None` not `Optional[str]`, `list[int]` not `List[int]`, generics as `def first[T](items: list[T]) -> T`.
- Use string literals `Literal["option1", "option2"]` for function arguments that can take multiple values.
- Extract type aliases when types are complex and/or appear in many places. For example `type OutputType = Literal["json", "txt", "csv"]`, `type InnerFunction = Callable[[pl.DataFrame, int], float]`.
- Import from `collections.abc` rather than `typing`.

## Testing

- Use `pytest`.
- Each test should test one specific behavior.
- Use descriptive test names and include a short, imperative docstring describing the intended functionality.
- Use test parameterization for similar tests.
- Use fixtures for shared setup. Built-in fixtures like `tmp_path: Path` and `monkeypatch: pytest.MonkeyPatch` are often useful.
- Don't mock internal modules. Only mock true external boundaries.
- Rerun the appropriate tests after substantive changes.

## Libraries

Use the libraries listed below when appropriate. Avoid using the libraries in the "Not" column. Ask before installing things not on this list.

Some of these libraries have their own skills. Load them when appropriate.
When there's no skill, refer to the sections below and use `context7` to search documentation with the provided key.

| Purpose | Use | Not | Documentation |
|---|---|---|---|
| Tabular data | polars | pandas | See skill. |
| CLI | cyclopts | argparse, click, typer | https://cyclopts.readthedocs.io/en/stable/getting_started.html |
| Figures | plotnine | matplotlib, seaborn | https://plotnine.org/guide/overview.html |
| HTTP | httpx (sync by default) | requests, urllib | https://www.python-httpx.org/quickstart/ |
| HTML parsing | parsel | BeautifulSoup, lxml | https://parsel.readthedocs.io/en/latest/usage.html |
| Structured data | pydantic or dataclasses | TypedDict, manual dicts | https://docs.pydantic.dev/latest/ |
| Logging | loguru | -- | https://loguru.readthedocs.io/en/stable/overview.html |

### plotnine

Python clone of ggplot from R. Prefer this for figures unless doing something very bespoke where the full power of matplotlib is required.

### httpx

Use the sync by default. Use a `Client` context manager for anything beyond a single one-off call. Call `raise_for_status()` rather than checking status codes manually.

### parsel

Prefer CSS selectors over XPath unless XPath is meaningfully simpler for the case (e.g. text-content ancestor lookups).

### pydantic

Reach for `BaseModel` any time data crosses a boundary (API responses, config, CLI-adjacent structured input) instead of raw dicts or dataclasses.

