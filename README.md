# alipatti

Personal Python helpers.

```sh
uv add "alipatti[plot] @ git+https://github.com/alipatti/alipatti.py"
```

## `alipatti.plots`

Helpers for plotnine figures, installed with the `plot` extra:

- `PALETTE` and `theme_ali()`: shared colors and a classic theme set in
  typst's default font.
- `math_font()`: a context manager that renders mathtext labels in the same
  font, restoring matplotlib's settings on exit.
- `center_panels()`: sets the right margin so panels sit horizontally centered.
- `save_figure()`: centers and saves a figure under `math_font()`.
