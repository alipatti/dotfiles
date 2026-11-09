// extra space around relations (and slashes) in display math, as in a = b.
// a relation is any character of unicode math class R
// (www.unicode.org/Public/math/revision-15/MathClass-15.txt, minus the daggers),
// so =, <=, ->, in, subset.eq, ... need no listing,
// or an attachment, stretch, or class built on one, like stretch(arrow.r)^p.
// sub- and superscripts are left alone, so sum_(i = 1) keeps its tight spacing.
// applied as a show rule; the source is written as usual.

#let relation-chars = regex(
  "^["
    + "\u{3c}-\u{3e}\u{2190}-\u{21b3}\u{21b6}-\u{21b7}\u{21ba}-\u{21ff}\u{2208}-\u{220d}"
    + "\u{221d}\u{2223}-\u{2226}\u{2234}-\u{2237}\u{2239}-\u{223d}\u{2241}-\u{228b}"
    + "\u{228f}-\u{2292}\u{22a2}-\u{22a3}\u{22a5}-\u{22b8}\u{22c8}\u{22cd}\u{22d0}-\u{22d1}"
    + "\u{22d4}-\u{22ff}\u{2322}-\u{2323}\u{233f}\u{237c}\u{23b0}-\u{23b1}\u{27c2}-\u{27cb}"
    + "\u{27cd}\u{27d2}-\u{27d4}\u{27da}-\u{27df}\u{27f0}-\u{27ff}\u{2900}-\u{297f}"
    + "\u{29ce}-\u{29d5}\u{29df}\u{29e1}\u{29e3}-\u{29e6}\u{29f4}\u{2a59}\u{2a66}-\u{2a70}"
    + "\u{2a73}-\u{2ae0}\u{2ae2}-\u{2af0}\u{2af2}-\u{2af3}\u{2af7}-\u{2afa}\u{2b00}-\u{2b11}"
    + "\u{2b30}-\u{2b4c}\u{2b95}"
    + "]$",
)

// math characters are symbol elements; quoted strings are text
#let symbol = $=$.body.func()
#let is-char(it) = it.func() in (symbol, text)

#let is-relation(it) = {
  let f = it.func()
  if is-char(it) {
    it.text.match(relation-chars) != none
  } else if f == math.class {
    it.class == "relation"
  } else if f == math.attach {
    is-relation(it.base)
  } else if f in (math.stretch, math.limits, math.scripts, math.equation) {
    is-relation(it.body)
  } else {
    false
  }
}

// pad relations in `it`, descending into groupings but not into attachments' scripts
#let pad-relations(it, space: 0.4em, slash-space: 0.15em) = {
  let pad = pad-relations.with(space: space, slash-space: slash-space)
  let f = it.func()
  let fields = it.fields()
  if is-relation(it) {
    h(space) + it + h(space)
  } else if is-char(it) and it.text == "/" {
    h(slash-space) + it + h(slash-space)
  } else if f == [].func() {
    it.children.map(pad).join()
  } else if f == math.equation {
    // macros like `to` are inline equations nested in the display
    pad(it.body)
  } else if f == math.lr {
    let body = pad(fields.remove("body"))
    math.lr(..fields, body)
  } else if f == math.frac {
    let num = pad(fields.remove("num"))
    let denom = pad(fields.remove("denom"))
    math.frac(..fields, num, denom)
  } else if f == math.root {
    let radicand = pad(it.radicand)
    if it.has("index") { math.root(it.index, radicand) } else { math.sqrt(radicand) }
  } else if f in (math.cases, math.vec) {
    let children = fields.remove("children").map(pad)
    f(..fields, ..children)
  } else if f == math.mat {
    let rows = fields.remove("rows").map(row => row.map(pad))
    math.mat(..fields, ..rows)
  } else {
    it
  }
}

#let relation-spacing(body, ..args) = {
  show math.equation.where(block: true): eq => {
    // the padded copy below is also a block equation, so stop at it
    if eq.at("label", default: none) == <relations-padded> { return eq }
    let fields = eq.fields()
    let body = fields.remove("body")
    let _ = fields.remove("label", default: none)
    // the copy steps the equation counter again, so undo the original's step
    if eq.numbering != none { counter(math.equation).update(n => n - 1) }
    [#math.equation(..fields, pad-relations(body, ..args)) <relations-padded>]
  }
  body
}
