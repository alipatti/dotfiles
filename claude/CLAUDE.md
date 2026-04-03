- Do not use emoji.
- Search documentation when encountering unfamiliar libraries or APIs.
- Extract helpers when logic is used 2+ times or when a name meaningfully clarifies intent.
- Write concise and imperative git commit messages.

## Python

- Write pythonic code: list comprehensions, pathlib, f-strings, itertools, functools, etc.
- Always include type hints. Use modern features when available (e.g. | for Union, parameterized functions with [T])
- Use whitespace to make your code more readable (e.g. separate if blocks with a blank newline).
- Avoid overly-defensive error handling.

### Tooling

- Use uv and pyproject.toml to manage dependencies.
- Use `ruff format` for formatting.
- Use `ruff check --fix` for linting.
- Use `pyright` for type checking.
- Run formatting, linting, and type checking after substantive changes.

### Libraries

- Use polars for data processing. Do not use pandas.
- Use cyclopts for CLIs.
- Use plotnine for figures.
- Use httpx for networking (sync by default).
- Use parsel for parsing html.
- Use stdlib logging for libraries. Use loguru for applications.
- Use pydantic for structured data.

### Documentation

- Write complete Numpy-style docstrings for public functions and classes.
- Write descriptive one-line docstrings for internal code.

### Testing

- Use pytest.
- Write short, specific tests with descriptive names.
- Prefer integration tests over unit tests where practical.
- Include a short, imperative docstring describing the intended functionality.
- Use fixtures for shared functionality.
- Avoid mocking internal modules.
- Rerun tests after substantive changes.
