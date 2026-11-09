// matching keys to table columns by their segments, for make-table's
// column-styles and rule-after. a column "a::b::c" has segments (a, b, c), and a
// key matches it when the key's segments occur there as a contiguous run, so "b",
// "a::b" and "b::c" match but "a::c" does not. a key matches as a column name when
// its run ends at the column's last segment, and as a group name otherwise

#let segments(name, delimiter) = if delimiter == none { (name,) } else { name.split(delimiter) }

// where key's segments end within each column they match, as (column index, matches as a column)
#let matches(key, names, delimiter) = {
  let key-segments = segments(key, delimiter)
  let n = key-segments.len()
  let found = ()
  for (x, name) in names.enumerate() {
    let column = segments(name, delimiter)
    for start in range(column.len() - n + 1) {
      if column.slice(start, start + n) == key-segments {
        found.push((x, start + n == column.len()))
      }
    }
  }
  assert(found.len() > 0, message: "make-table: " + repr(key) + " matches no column")
  assert(
    found.map(((_, leaf)) => leaf).dedup().len() == 1,
    message: "make-table: " + repr(key) + " matches both a column and a group",
  )
  found.map(((x, _)) => x).dedup()
}

// the merged style of every column: styles of longer keys override shorter ones,
// and keys of equal length must agree on the arguments they share
#let resolve-styles(names, column-styles, delimiter) = {
  let styles = names.map(_ => (:))
  let lengths = column-styles.keys().map(key => segments(key, delimiter).len()).dedup().sorted()
  for n in lengths {
    let level = names.map(_ => (:))
    for (key, style) in column-styles {
      if segments(key, delimiter).len() != n { continue }
      for x in matches(key, names, delimiter) {
        for (arg, value) in style {
          let other = level.at(x).at(arg, default: value)
          assert(
            other == value,
            message: "make-table: column-styles set " + arg + " differently on " + repr(names.at(x)),
          )
        }
        level.at(x) += style
      }
    }
    styles = styles.zip(level).map(((style, more)) => style + more)
  }
  styles
}

// indices of the columns with a rule on their left: after the last column of each
// run of columns that some key matches
#let rule-columns(names, keys, delimiter) = {
  let columns = ()
  for key in keys {
    let xs = matches(key, names, delimiter)
    columns += xs.filter(x => x + 1 not in xs).map(x => x + 1)
  }
  columns.dedup()
}
