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
and provides theorem environments (theorion), cetz/fletcher/subpar, math macros
(`inner`, `to`, `toto`, ...), and all document styling.
Do not re-add set/show rules the template already handles.

Style:

- Put tables inside floats:
  wrap them in `#figure(...)` with a caption rather than placing them bare in
  the text.
- Lean towards display math with delimiters on their own lines instead of
  cramming expressions inline.
- Math is part of the sentence: let prose flow through displays,
  with punctuation inside the math block.
- Use the template's macros (`to`, `toto`, `inner`, ...) instead of raw symbols.
- After a formal definition or theorem, add a short informal gloss
  ("Informally, ...").
- Before a long computation or notation-heavy section,
  give an intuitive overview of what's to come.
- Prefer algebraic-flavored exposition: maps, spaces, commutative diagrams
  (fletcher).

Notation:

- Use parentheses for grouping and function application.
  Use other groupings (e.g. $[$, $\{$) only when explicitly necessary.
- Use $EE(...)$ for expectation
  (blackboard + parentheses, not square brackets).
