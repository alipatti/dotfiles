---
name: typst
description: Use this skill when writing or editing Typst documents (.typ files), e.g. notes or problem sets.
---

# Typst Skill

Start every new document with the personal template:

```typst
#import "@ali/template:0.1.0": *
#show: template
```

It lives in `~/.dotfiles/typst/template/`
and provides theorem environments (theorion), cetz/fletcher/subpar,
math macros (`inner`, `to`, `toto`, ...), and all document styling.
Do not re-add set/show rules the template already handles.

There is no need to compile after every change.

## General Style

- Be concise and assume that your reader is very intelligent.
  Err on the side of brevity and omitting details in the first pass.
  If more detail is needed, it will be requested.
- After a formal definition or theorem, add a short informal gloss
  ("Informally, ...").
- Before a long computation or notation-heavy section,
  give an intuitive overview of what's to come.
- Prefer algebraic-flavored exposition: maps, spaces, commutative diagrams
  (using `fletcher`).
- Place each sentence on its own own line in the source file.

## Formatting Math

- Default to display math; inline math is the exception.
  Inline math is for naming objects, not for stating results.
  Displays are indented two spaces, with the delimiters on their own lines.
- Math is part of the prose.
  Display blocks should end with appropriate punctuation:
  for example a comma when they lead into a separate clause,
  or a period when they end a sentence.
- Never start a sentence with a mathematical symbol.
- When simplifying complicated expressions or showing
  that two things are equal, use "Oklahoma" style:
  Place the initial object on the left-hand side of the first line,
  and then place every subsequent step on the right-hand side on their own
  lines (so the rendered text looks like the outline of Oklahoma.) Never
  simplify both sides of the equation simultaneously.
  See below for an example.

### Notation

- Use parentheses for grouping and function application.
  Use other groupings (e.g. `[`, `{`) only when explicitly necessary.
- Use `$EE(...)$` for expectation
  (blackboard + parentheses, not square brackets).
- Use the provided template's macros
  (`to`, `toto`, `inner`, ...) instead of raw symbols.

### Minimal Math Example

```typst
// this math is simple enough to be inline
Let $X ~ "Pareto"(x_min, alpha)$ with $alpha > 1$.
Direct calculation gives
$
  // "Oklahoma" math
  EE(X) & = integral_(x_min)^infinity x dot alpha thin x_min^alpha thin x^(-(alpha + 1)) dif x \
        & = alpha thin x_min^alpha thin (x^(1 - alpha) / (1 - alpha))_(x_min)^infinity \
        & = (alpha thin x_min) / (alpha - 1),
$
where the last line uses $x^(1 - alpha) to 0$ as $x to infinity$.
Inverting and plugging in the sample mean yields the estimator
$
  // this math is short, but we still put it in a display because it's important
  hat(alpha) = macron(X) / (macron(X) - x_min).
  //                                          ^ ends with a period
$
// we add "The estimator ..." to avoid starting a sentence with a symbol
The estimator $hat(alpha)$ is consistent by the continuous mapping theorem.
```

### Inline vs. Display

Bad:

```typst
Its moments are $EE(X) = mu = m$, $var(X) = sigma^2 + tau^2 = s$, and $cov(X, Y) = rho$.
```

Good:

```typst
Its moments are
$
  EE(X) & = mu = m, \
  var(X) & = sigma^2 + tau^2 = s, \
  cov(X, Y) & = rho.
$
```

## Tables

- Put tables inside floats:
  wrap them in `#figure(...)` with a caption rather than placing them bare
  in the text.
- Build tables of computed results with the template's `make-table`,
  fed by a csv that the analysis code writes.
  The code writes raw numbers at full precision
  and Typst does all the formatting
  (decimals, thousands separators, minus signs, percents).
- The csv _is_ the content of table: the code chooses its columns,
  their order, and their display names.
  The header becomes the table header,
  and header names and facet values may be Typst markup (e.g. `$tau$`).
- Put a column's standard error in a column named `<column>_se`;
  `make-table` sets it in parentheses below the estimate.
- To split one table into lettered panels ("Panel A: ..."),
  include a column to `facet`.
- Pass per-column formatting with `column-styles`
  (`num` arguments: `digits`, `percent`).
  Numbers default to 3 digits, integers to 0.
- Mark column groups with `rule-after` (column names);
  there is no need for other rules.
- Wrap the result in `#figure` with a caption that defines every symbol.
- The figure's kind is inferred, so no need to pass `kind: table`.

### Minimal Table Example

```typst
#figure(
  make-table(
    csv("numbers/estimates.csv", row-type: dictionary),
    facet: "Parameter",
    column-styles: ("$tau$": (digits: 1), "ESS / Sec.": (digits: 0)),
    rule-after: ("Sampler", "75th Pct."),
  ),
  caption: [...],
) <tab:estimates>
```
