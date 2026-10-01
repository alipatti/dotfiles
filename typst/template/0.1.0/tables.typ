// tables from csv data; only make-table is exported by lib.typ

// fixed decimals, thousands separators, and a real minus sign, e.g. num(-1234.5, digits: 1) = −1,234.5;
// with percent, the value is a share shown in percent, e.g. num(0.0036, digits: 2, percent: true) = 0.36%
#let num(value, digits: 3, percent: false) = {
  let x = float(value) * if percent { 100 } else { 1 }
  let (whole, ..fraction) = str(calc.round(calc.abs(x), digits: digits)).split(".")
  let fraction = fraction.at(0, default: "")
  let grouped = whole.clusters().rev().chunks(3).map(group => group.rev().join()).rev().join(",")
  let sign = if x < 0 and calc.round(x, digits: digits) != 0 { "−" } else { "" }
  sign + grouped + if digits > 0 { "." + fraction + "0" * (digits - fraction.len()) } + if percent { "%" }
}

// rule under the header and on the left of the given column indices
#let rules(header-rows: 1, after-columns: (1,)) = (x, y) => (
  left: if x in after-columns { 0.5pt } else { 0pt },
  bottom: if y == header-rows - 1 { 0.5pt } else { 0pt },
)

// italic title just above a table, hanging slightly past its left edge
#let panel(title, body) = box(stack(
  spacing: 1em,
  align(left, move(dx: -1.5em, emph(title))),
  body,
))

// a table from csv rows read with `csv(..., row-type: dictionary)`, whose header
// names the columns. header names and facet values are typst markup, e.g.
// "$tau$"; other text cells are too with markup-cells. the first column labels
// the rows. a column named "x" + se-suffix is set below column "x" as its
// standard error. facet splits the rows into lettered panels by that column.
// column-styles maps column names to `num` arguments; numbers default to 3
// digits, or 0 for integers, and standard errors get one more digit than their
// column. rule-after names columns followed by a rule.
#let make-table(
  rows,
  facet: none,
  se-suffix: "_se",
  column-styles: (:),
  rule-after: auto,
  markup-cells: false,
) = {
  let names = rows.first().keys().filter(name => name != facet and not name.ends-with(se-suffix))
  let rule-after = if rule-after == auto { (names.first(),) } else { rule-after }
  for name in rule-after {
    assert(name in names, message: "make-table: no column " + repr(name) + " to put a rule after")
  }

  let markup(text) = eval(text, mode: "markup")
  let format(value, style) = {
    if value.match(regex("^-?\\d*\\.?\\d+([eE][-+]?\\d+)?$")) == none {
      return if markup-cells { markup(value) } else { value }
    }
    let digits = style.at("digits", default: if value.contains(regex("[.eE]")) { 3 } else { 0 })
    num(value, ..style, digits: digits)
  }
  let cell(row, name) = {
    let style = column-styles.at(name, default: (:))
    let value = format(row.at(name), style)
    let se = row.at(name + se-suffix, default: none)
    if se == none { return value }
    let se-style = style + (digits: style.at("digits", default: 3) + 1)
    [#value \ #text(0.8em)[(#format(se, se-style))]]
  }
  let body(rows) = table(
    columns: names.len(),
    align: (left,) + (center,) * (names.len() - 1),
    stroke: rules(after-columns: rule-after.map(name => names.position(n => n == name) + 1)),
    table.header(..names.map(markup)),
    ..rows.map(row => names.map(name => cell(row, name))).flatten(),
  )

  if facet == none { return body(rows) }
  let values = rows.map(row => row.at(facet)).dedup()
  stack(
    spacing: 2em,
    ..values
      .enumerate()
      .map(((i, value)) => panel(
        [Panel #numbering("A", i + 1): #markup(value)],
        body(rows.filter(row => row.at(facet) == value)),
      )),
  )
}
