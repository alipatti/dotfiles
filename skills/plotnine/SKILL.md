---
name: plotnine
description: "Use this skill when making figures in Python. Covers visual style and shared helpers in the users personal package. Load the python skill first."
---

# plotnine

- Import as `import plotnine as pn` and reference everything as `pn.XXX`.
- Use the helpers in `ap.plot` rather than reimplementing them.
  Install with
  `uv add "alipatti[plot] @ git+https://github.com/alipatti/alipatti.py"`.
  This contains a theme, color palates, saving helpers, etc.

```python
import alipatti as ap
import plotnine as pn

figure = pn.ggplot(df, pn.aes("x", "y")) + pn.geom_line() + ap.plot.theme_ali()
ap.plot.save_figure(figure, "trend")  # figures/trend.pdf
```

## Iterating on Figures

- Write plotting functions that return a `pn.ggplot` without saving it.
  That way, callers can display, extend, or save the plot as they choose.
- While iterating, save a PNG from a scratch script
  (`figure.save("scratch/trend.png", dpi=150)`)
  and look at it with the Read tool.
  Check labels, scales, overlapping text, and legend placement,
  and stop after a few rounds rather than polishing indefinitely.
- Save the final version with `ap.plot.save_figure`.
