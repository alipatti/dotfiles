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

## Style

- Put tables inside floats:
  wrap them in `#figure(...)` with a caption rather than placing them bare
  in the text.
- Lean towards display math with delimiters on their own lines instead of
  cramming expressions inline.
- Math is part of the sentence: let prose flow through displays,
  with punctuation inside the math block.
- Use the template's macros
  (`to`, `toto`, `inner`, ...) instead of raw symbols.
- After a formal definition or theorem, add a short informal gloss
  ("Informally, ...").
- Before a long computation or notation-heavy section,
  give an intuitive overview of what's to come.
- Prefer algebraic-flavored exposition: maps, spaces, commutative diagrams
  (fletcher).

## Tables of Results

- Build tables of computed results with the template's `make-table`,
  fed by a csv that the analysis code writes.
  The code writes raw numbers at full precision
  and Typst does all the formatting
  (decimals, thousands separators, minus signs, percents).
- The csv is the table: the code chooses its columns, their order,
  and their display names.
  The header becomes the table header,
  and header names and facet values may be Typst markup (e.g. `$tau$`).
- Put a column's standard error in a column named `<column>_se`;
  `make-table` sets it in parentheses below the estimate.
- To split one table into lettered panels ("Panel A: ..."),
  include a column to `facet` by rather than writing several csvs.
- Pass per-column formatting with `column-styles`
  (`num` arguments: `digits`, `percent`).
  Numbers default to 3 digits, integers to 0.
- Mark column groups with `rule-after` (column names);
  there is no need for other rules.
- Wrap the result in `#figure` with a caption that defines every symbol;
  the figure's kind is inferred, so don't pass `kind: table`.

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

## Notation

- Use parentheses for grouping and function application.
  Use other groupings (e.g. $[$, $\{$) only when explicitly necessary.
- Use $EE(...)$ for expectation
  (blackboard + parentheses, not square brackets).
