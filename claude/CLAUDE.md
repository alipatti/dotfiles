- Be direct and concise.
- Do not use emoji.
- Search documentation when encountering unfamiliar libraries or APIs.
- Prefer modern Unix utilities (rg, fd, jq) when available.
- Split repeated or self-contained tasks into helper functions with clear names.

## Python

- Write pythonic code: list comprehensions, pathlib, f-strings, itertools, functools, etc.
- Always include type hints. Use modern features when available (e.g. | for Union, parameterized functions with [T])
- Use whitespace to make your code more readable (e.g. separate if blocks with a blank newline).
- Use uv and pyproject.toml to manage dependencies.

### Libraries

- Use polars for data processing. Do not use pandas.
- Use cyclopts for CLIs.
- Use plotnine for figures.
- Use pytest for tests.

