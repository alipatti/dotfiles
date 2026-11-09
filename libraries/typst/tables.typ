// tables from csv data; make-table is exported by lib.typ

#import "columns.typ": resolve-styles, rule-columns
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
// names the columns and whose first column labels the rows
#let make-table(
  rows,
  // column whose values split the rows into lettered panels
  facet: none,
  // a column named "x" + se-suffix is set in parentheses below column "x" as its standard error
  se-suffix: "_se",
  // a header "group" + delimiter + "name" sets "name" under a "group" header
  // spanning the adjacent columns of that group
  group-delimiter: none,
  // maps keys to `format-num` arguments; numbers default to 3 digits, or 0 for
  // integers, and standard errors get one more digit than their column. keys match
  // columns by segments (see columns.typ), so "RMSE" styles every "group::RMSE".
  // styles of longer keys override shorter ones
  column-styles: (:),
  // keys, matched as in column-styles, with a rule after the columns they match;
  // default: the first column
  rule-after: auto,
  // row labels with a rule above every row carrying them, in every panel
  rule-above: (),
  // evaluate non-numeric body cells as typst markup, like the header and facet values
  markup-cells: true,
) = {
  let names = rows.first().keys().filter(name => name != facet and not name.ends-with(se-suffix))

  // (group, label) of a column, where group is none for an ungrouped column
  let split(name) = {
    if group-delimiter == none or not name.contains(group-delimiter) { return (none, name) }
    let (group, ..label) = name.split(group-delimiter)
    (group, label.join(group-delimiter))
  }
  let groups = names.map(name => split(name).first())

  let rule-after = if rule-after == auto { (names.first(),) } else { rule-after }
  let after-columns = rule-columns(names, rule-after, group-delimiter)
  let styles = resolve-styles(names, column-styles, group-delimiter)

  let labels = rows.map(row => row.at(names.first()))
  for label in rule-above {
    assert(label in labels, message: "make-table: no row " + repr(label) + " to put a rule above")
  }

  let markup(text) = eval(text, mode: "markup")
  let format(value, style) = format-value(value, markup: markup-cells, ..style)
  let cell(row, x) = {
    let name = names.at(x)
    let style = styles.at(x)
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
    ..rows
      .enumerate()
      .map(((y, row)) => {
        let rule = if row.at(names.first()) in rule-above { (table.hline(y: header-rows + y, stroke: 0.5pt),) } else { () }
        rule + range(names.len()).map(x => cell(row, x))
      })
      .flatten(),
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
