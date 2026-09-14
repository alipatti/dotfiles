// theorems (re-exported: theorem, definition, corollary, proof, ...)
#import "@preview/theorion:0.6.0": *
#import cosmos.rainbow: *

// figures and diagrams (re-exported)
#import "@preview/subpar:0.2.2"
#import "@preview/cetz:0.4.2": canvas, draw
#import "@preview/fletcher:0.5.8" as fletcher: diagram, edge, node

// macros
#let todo(x) = "TODO: " + x
#let inner(x, y) = $chevron.l x, y chevron.r$
#let to = $arrow.r$
#let of = $circle.small$
#let toto = $arrows.rr$
#let End = $op("End")$
#let poly = $op("poly")$

// run-in level-3 headings: show rules can't look ahead, so a flag marks
// the blank line right after a heading to be dropped instead of starting a new paragraph
#let after-runin = state("after-runin", false)

#let template(body) = {
  show: show-theorion

  // reference theorem-like environments as "<title> (<number>)",
  // e.g. "Berge (1.2.4)", falling back to theorion's default when untitled
  show ref: it => {
    let el = it.element
    if el != none and el.func() == figure and type(el.kind) == str and it.supplement == auto {
      let title = el.caption.body
      if title != none and title != [] and title != [#""] {
        context link(el.location(), [#title (#theorion-display-number(el))])
      } else {
        it
      }
    } else {
      it
    }
  }

  // fonts
  set text(font: "New Computer Modern", size: 10pt, lang: "en")
  show math.equation: set text(font: "New Computer Modern Math")

  // spacing
  set page(paper: "us-letter", margin: 1in)
  set list(indent: 1em)
  set enum(indent: 1em)
  show sym.eq: it => h(0.2em) + it + h(0.2em)
  set par(justify: true, leading: 0.6em, first-line-indent: 0em, spacing: 1em)

  // numbering
  set enum(numbering: "(a)")
  set heading(numbering: "1.1")
  set math.equation(numbering: "(1)")

  // headings
  show heading.where(level: 1): it => {
    set text(size: 1em, weight: "bold")
    v(2em, weak: true)
    it
    v(1em, weak: true)
  }
  show heading.where(level: 2): it => {
    set text(size: .9em, weight: "bold")
    v(1.5em, weak: true)
    it
    v(1em, weak: true)
  }
  show heading.where(level: 3): it => {
    after-runin.update(true)
    text(style: "italic", weight: "regular", it.body + [. ])
  }
  show parbreak: it => context if after-runin.get() {
    after-runin.update(false)
  } else {
    it
  }

  show title: it => {
    align(center)[#it]
  }

  // tables
  set table(stroke: (x, y) => (
    left: if x > 0 { 0.5pt } else { 0pt },
    bottom: if y == 0 { 0.5pt } else { 0pt },
  ))

  // figures
  set figure(gap: 2em, placement: top)
  show figure.caption: it => {
    smallcaps[#it.supplement #context it.counter.display(it.numbering)]
    it.separator
    it.body
  }

  body
}
