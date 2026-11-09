// tables from csv data; make-table is exported by lib.typ

#import "format.typ": format-value

// rule on the left of the given column indices
#let rules(after-columns: (1,)) = (x, y) => (
  left: if x in after-columns { 0.5pt } else { 0pt },
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
// column-styles maps column names to `format-num` arguments; numbers default to 3
// digits, or 0 for integers, and standard errors get one more digit than their
// column. with a group-delimiter, a header "group" + delimiter + "name" sets
// "name" under a "group" header spanning the adjacent columns of that group.
// rule-after names columns, or groups, followed by a rule.
#let make-table(
  rows,
  facet: none,
  se-suffix: "_se",
  column-styles: (:),
  rule-after: auto,
  markup-cells: false,
  group-delimiter: none,
) = {
  let names = rows.first().keys().filter(name => name != facet and not name.ends-with(se-suffix))

  // (group, label) of a column, where group is none for an ungrouped column
  let split(name) = {
    if group-delimiter == none or not name.contains(group-delimiter) { return (none, name) }
    let (group, ..label) = name.split(group-delimiter)
    (group, label.join(group-delimiter))
  }
  let groups = names.map(name => split(name).first())

  // a rule after a group goes after its last column
  let last-column(name) = {
    let index = names.position(n => n == name)
    if index != none { return index }
    let index = groups.rev().position(group => group == name)
    assert(index != none, message: "make-table: no column or group " + repr(name) + " to put a rule after")
    names.len() - 1 - index
  }
  let rule-after = if rule-after == auto { (names.first(),) } else { rule-after }
  let after-columns = rule-after.map(name => last-column(name) + 1)

  let markup(text) = eval(text, mode: "markup")
  let format(value, style) = format-value(value, markup: markup-cells, ..style)
  let cell(row, name) = {
    let style = column-styles.at(name, default: (:))
    let value = format(row.at(name), style)
    let se = row.at(name + se-suffix, default: none)
    if se == none { return value }
    let se-style = style + (digits: style.at("digits", default: 3) + 1)
    [#value \ #text(0.8em)[(#format(se, se-style))]]
  }

  // runs of adjacent columns sharing a group, as (group, first column, column count)
  let runs = groups
    .enumerate()
    .fold((), (runs, (x, group)) => {
      if group != none and runs.len() > 0 and runs.last().first() == group {
        let (_, start, count) = runs.pop()
        runs.push((group, start, count + 1))
      } else {
        runs.push((group, x, 1))
      }
      runs
    })
  let grouped = groups.any(group => group != none)
  let header-rows = if grouped { 2 } else { 1 }
  let header = if not grouped { names.map(markup) } else {
    // ungrouped columns span both header rows, sitting on the lower one beside the
    // column labels, and group names are underlined
    let top = runs.map(((group, start, count)) => if group == none {
      table.cell(rowspan: 2, align: bottom + if start == 0 { left } else { center }, markup(names.at(start)))
    } else {
      table.cell(colspan: count, underline(offset: 0.3em, markup(group)))
    })
    let labels = names.filter(name => split(name).first() != none).map(name => markup(split(name).last()))
    (..top, ..labels)
  }

  let body(rows) = table(
    columns: names.len(),
    align: (left,) + (center,) * (names.len() - 1),
    stroke: rules(after-columns: after-columns),
    table.header(..header, table.hline(y: header-rows, stroke: 0.5pt)),
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
