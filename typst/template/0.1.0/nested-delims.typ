// grow matched delimiters by nesting depth so ((x + 10) * 5) reads as
// ( (x + 10) * 5 ) even when the inner content is all the same height.
// typst only sizes delimiters by content height (see typst/typst#360).
// applied as a show rule; the source is written as usual.

// count how deeply math.lr elements nest inside `c`
#let lr-depth(c) = {
  if type(c) == array { return c.map(lr-depth).fold(0, calc.max) }
  if type(c) != content { return 0 }
  let inner = c.fields().values().map(lr-depth).fold(0, calc.max)
  if c.func() == math.lr { inner + 1 } else { inner }
}

// `grow` is the extra size per nesting level, `max-depth` caps the growth
// so a paren around a tall sum doesn't balloon
#let nested-delims(body, grow: 20%, max-depth: 3) = {
  show math.lr: it => {
    // only touch default-sized delimiters; an explicit lr(size: ...) is
    // respected, and this stops the rule matching its own output
    if it.size != 100% { return it }
    let d = calc.min(lr-depth(it.body), max-depth)
    if d == 0 { return it }
    math.lr(size: 100% + grow * d, it.body)
  }
  body
}
