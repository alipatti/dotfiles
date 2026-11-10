---
name: typst
description: Use this skill when writing or editing Typst documents (.typ files), e.g. notes or problem sets.
---

# Typst Skill

Start every new document with the personal template,
imported as a namespace:

```typst
#import "@ali/template:<version>" as ali
#import ali: cov, var // only the math macros the document uses
#show: ali.template
```

It lives in `$DOTFILES/libraries/typst/`.
New documents use the newest version, the `version` in its `typst.toml`.
Leave existing imports alone.
The template provides theorem environments (theorion),
cetz/fletcher/subpar, math macros
(`inner`, `to`, `toto`, ...), table helpers, and all document styling.
Do not reimplement set/show rules the template already provides.

Refer to everything through the namespace
(`ali.make-table`, `ali.format-num`, `ali.clearpage()`),
except math macros.
Import those by name: `$ali.var(X)$` is noisy in equations.

There is no need to compile after every change.

## General Style

- Be concise and assume that your reader is very intelligent.
  Err on the side of brevity and omitting details in the first pass.
  If more detail is needed, it will be requested.
- Prefer algebraic-flavored exposition: maps, spaces, commutative diagrams
  (using `fletcher`).
- Use plain connecting prose,
  e.g. "From lecture, ...", "We know that ...", "Therefore, ...", "So ...".
- Don't overly formalize.
- In general, prefer common words to jargon when jargon is not needed,
  e.g. "distribution" over "law".
- Prefer a short list when checking or listing several assumptions
  or conditions rather than cramming them all inline.
- Place each sentence on its own line in the source file.
- Start appendices with `#show: ali.appendix`.

### Punctuation

- Use commas only where grammar or clarity requires them.
  For example, do not put a comma before a trailing prepositional phrase:
  write "The acceptance rate
  and speed of each sampler over the retained draws" rather than "The
  acceptance rate and speed of each sampler, over the retained draws".
- Do not use semicolons.

## Writing Math

### Display vs Inline

- Display results, derivations, and anything the argument turns on.
  Inline short facts that only name or describe an object.
- Keep the prose leading into a display short;
  if it needs more than one or two inline expressions,
  display one of them or reconsider the framing.
- Displays are indented two spaces, with the delimiters on their own lines.

Bad:

```typst
Since
$
  // trivial facts don't need a display
  EE(Z_j^2) & = 1, \
  var(Z_j^2) & = 2,
$
// the result is what the argument turns on, so it shouldn't be inline
the CLT gives $(W_m - m) slash sqrt(2 m) => cal(N)(0, 1)$.
```

Good:

```typst
// short facts that describe an object are inline
Since $Z_j^2$ has mean 1 and variance 2, the CLT gives
$
  // the result gets a display
  (W_m - m) / sqrt(2 m) => cal(N)(0, 1).
$
```

### Math in Prose

- Math is part of the prose.
  Display blocks should end with appropriate punctuation:
  for example a comma when they lead into a separate clause,
  or a period when they end a sentence.
- Never start a sentence with a mathematical symbol.
- Keep inline math to the objects themselves
  and say logic in words,
  e.g. "$x_i$ and $u_i$ are independent", not "$x_i perp u_i$".
- When invoking a lemma or earlier result,
  apply it in exactly its stated form.
- Introduce notation only at the point where it's needed.

### Long Displays

- When simplifying complicated expressions or showing
  that two things are equal, use "Oklahoma" style:
  Place the initial object on the left-hand side of the first line,
  and then place every subsequent step on the right-hand side on their own
  lines (so the rendered text looks like the outline of Oklahoma.) Never
  simplify both sides of the equation simultaneously.
  See below for an example.
- For a non-obvious equality, show one or two intermediate lines
  and highlight groupings with parentheses, `dot`s, etc.
- When several items share a relation, align on it.

### Notation

- Use parentheses for grouping and function application.
  Use other groupings (e.g. `[`, `{`) only when explicitly necessary.
- Use `$EE(...)$` for expectation (not square brackets).
- Use `$cal(N)$` for the normal distribution.
- Use `$exp(...)$` rather than `$e^(...)$`
  when the exponent is more than a symbol.
- Inside `sqrt`, use `slash` for small fractions, e.g. `$sqrt(2 slash n)$`.
- Use the provided template's macros
  (`to`, `toto`, `inner`, `iid`, ...) instead of raw symbols,
  imported by name.
- Be careful with subscripts: $f_k(x)$ is rendered with all of $k(x)$ as a subscript. Use $f_k (x)$ instead.

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

## Tables

- Put tables inside floats:
  wrap them in `#figure(...)` with a caption rather than placing them bare
  in the text.
- Build tables of computed results with the template's `ali.make-table`,
  fed by a csv that the analysis code writes.
  The code writes raw numbers at full precision
  and Typst does all the formatting
  (decimals, thousands separators, minus signs, percents).
- The csv _is_ the content of table: the code chooses its columns,
  their order, and their display names.
  The header becomes the table header,
  and header names, facet values and text cells are Typst markup (e.g. `$tau$`).
- Put a column's standard error in a column named `<column>_se`;
  `make-table` sets it in parentheses below the estimate.
- To split one table into lettered panels ("Panel A: ..."),
  include a column to `facet`.
- To group columns under a spanning header,
  name them `group::column` and pass `group-delimiter: "::"`.
- Pass per-column formatting with `column-styles`
  (`ali.format-num` arguments: `digits`, `percent`).
  Numbers default to 3 digits, integers to 0.
  A key matches a contiguous run of a column's `::` segments,
  so `"RMSE"` styles every `group::RMSE` and `"group"` every column in the group;
  longer keys override shorter ones.
- Mark column groups with `rule-after` (keys matched as in `column-styles`)
  and row groups with `rule-above` (row labels, i.e. first-column values);
  there is no need for other rules.
- Wrap the result in `#figure` with a caption that defines every symbol.
- The figure's kind is inferred, so no need to pass `kind: table`.

### Minimal Table Example

```typst
#figure(
  ali.make-table(
    csv("numbers/estimates.csv", row-type: dictionary),
    facet: "Parameter",
    column-styles: ("$tau$": (digits: 1), "ESS / Sec.": (digits: 0)),
    rule-after: ("Sampler", "75th Pct."),
  ),
  caption: [...],
) <tab:estimates>
```

## Computed Numbers in Text

- Don't hard-code computed numbers
  (draw counts, test statistics, ...) in the prose.
  Have the analysis code write them to a json file next to its csvs,
  load it with `json(...)`, and format with `ali.format-num`
  (integers default to 0 digits, other numbers to 3).
- To quote a value from a table's csv,
  use `ali.format-cell(rows, key, column, ..style)`,
  which formats it as `make-table` would.
  The key is a row label or a dictionary of column values;
  `ali.find-row(rows, key)` returns the raw row for arithmetic.
- `ali.format-num` also works inside math,
  e.g. `$[#ali.format-num(x), #ali.format-num(y)]$`.
  For a document-wide style, partially apply it:
  `#let num = ali.format-num.with(digits: 2)`.

```typst
#let settings = json("numbers/settings.json")
#let estimates = csv("numbers/estimates.csv", row-type: dictionary)

We keep #ali.format-num(settings.draws) draws,
and the slice sampler's ESS per second for $tau$ is
#ali.format-cell(estimates, (Sampler: "Slice", Parameter: "$tau$"), "ESS / Sec.").
```
