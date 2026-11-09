// single values from csv data for the prose; find-row and format-cell are exported by lib.typ

#import "format.typ": format-value

// the one row of `rows` (read with `csv(..., row-type: dictionary)`) matching
// `key`, as a dictionary of raw csv strings. a string key matches the first
// column, the row label as in make-table; a dictionary key matches every column
// it names, e.g. (Method: "Adaptive", Level: "67%")
#let find-row(rows, key) = {
  let matches = if type(key) == str {
    let label = rows.first().keys().first()
    rows.filter(row => row.at(label) == key)
  } else {
    rows.filter(row => key.pairs().all(((column, value)) => row.at(column) == value))
  }
  assert(matches.len() == 1, message: "find-row: " + str(matches.len()) + " rows match " + repr(key))
  matches.first()
}

// the value in the exact csv column `column` of the row matching `key`, as
// make-table shows it: numbers through format-num with `style` (digits, percent),
// other text as typst markup
#let format-cell(rows, key, column, ..style) = format-value(find-row(rows, key).at(column), ..style)
