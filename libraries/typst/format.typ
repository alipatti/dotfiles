// formatting csv values; format-num is exported by lib.typ

// fixed decimals, thousands separators, and a real minus sign, e.g. format-num(-1234.5, digits: 1) = −1,234.5;
// with percent, the value is a share shown in percent, e.g. format-num(0.0036, digits: 2, percent: true) = 0.36%.
// digits defaults to 0 for integers (including integer strings from csvs) and 3 otherwise
#let format-num(value, digits: auto, percent: false) = {
  let integer = type(value) == int or (type(value) == str and not value.contains(regex("[.eE]")))
  let digits = if digits == auto { if integer { 0 } else { 3 } } else { digits }
  let x = float(value) * if percent { 100 } else { 1 }
  let (whole, ..fraction) = str(calc.round(calc.abs(x), digits: digits)).split(".")
  let fraction = fraction.at(0, default: "")
  let grouped = whole.clusters().rev().chunks(3).map(group => group.rev().join()).rev().join(",")
  let sign = if x < 0 and calc.round(x, digits: digits) != 0 { "−" } else { "" }
  sign + grouped + if digits > 0 { "." + fraction + "0" * (digits - fraction.len()) } + if percent { "%" }
}

// a csv string: numbers through format-num with the given style, other text
// as typst markup, or verbatim without markup
#let format-value(value, markup: true, ..style) = {
  if value.match(regex("^-?\\d*\\.?\\d+([eE][-+]?\\d+)?$")) == none {
    return if markup { eval(value, mode: "markup") } else { value }
  }
  format-num(value, ..style)
}
