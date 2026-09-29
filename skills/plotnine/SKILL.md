---
name: plotnine
description: "Use this skill when making figures in Python. Covers visual style and shared helpers in the users personal package. Load the python skill first."
---

# plotnine

- Import as `import plotnine as pn` and reference everything as `pn.XXX`.
- Use the helpers in `alipatti.plots` rather than reimplementing them.
  Install with
  `uv add "alipatti[plot] @ git+https://github.com/alipatti/alipatti.py"`.
  This contains a theme, color palates, saving helpers, etc.

```python
import alipatti.plots as ap_plots
import plotnine as pn

figure = pn.ggplot(df, pn.aes("x", "y")) + pn.geom_line() + ap_plots.theme_ali()
ap_plots.save_figure(figure, "trend")  # figures/trend.pdf
```
