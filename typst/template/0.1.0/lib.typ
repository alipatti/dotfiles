// theorems (re-exported: theorem, definition, corollary, proof, ...)
#import "@preview/theorion:0.6.0": *
#import cosmos.rainbow: *

// figures and diagrams (re-exported)
#import "@preview/subpar:0.2.2"
#import "@preview/cetz:0.4.2": canvas, draw
#import "@preview/fletcher:0.5.8" as fletcher: diagram, edge, node

// grow nested delimiters by depth
#import "nested-delims.typ": nested-delims

// tables from csv data
#import "tables.typ": make-table

// macros
#let todo(x) = "TODO: " + x
#let inner(x, y) = $chevron.l #x, #y chevron.r$
#let to = $arrow.r$
#let of = $med circle.small med$
#let toto = $arrows.rr$
#let End = $op("End")$
#let poly = $op("poly")$
#let var = $op("Var")$
#let cov = $op("Cov")$
#let st = $op("s.t.")$

// probability and convergence
#let pto = $stretch(arrow.r)^p$
#let dto = $stretch(arrow.r)^d$
#let asto = $stretch(arrow.r)^"a.s."$
#let qmto = $stretch(arrow.r)^2$
#let ind = $bb(1)$
#let supp = $op("supp")$
#let argmax = $op("arg" thin "max", limits: #true)$

// equivalent of latex's \clearpage: place pending floats, then start a new page
#let clearpage() = {
  place.flush()
  pagebreak(weak: true)
}

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
  show: nested-delims

  // links (including references and citations)
  show link: set text(fill: rgb("#1f4e9c"))

  // spacing
  set page(paper: "us-letter", margin: 1in, numbering: "1")
  set list(indent: 1em, marker: context box(width: 0.4em, height: 0.07em, fill: text.fill, baseline: -0.26em))
  set enum(indent: 1em)
  set par(justify: true, leading: 0.6em, first-line-indent: 0em, spacing: 1em)

  // add extra space around relations in display math
  let relations = (
    sym.eq,
    sym.eq.not,
    sym.lt,
    sym.gt,
    sym.lt.eq,
    sym.gt.eq,
    sym.tilde.op,
    sym.approx,
    sym.equiv,
    sym.prop,
  )
  show math.equation.where(block: true): eq => relations.fold(eq, (acc, rel) => {
    show rel: it => h(0.4em) + it + h(0.4em)
    acc
  })
  show math.equation.where(block: true): eq => {
    show sym.slash: it => h(0.15em) + it + h(0.15em)
    eq
  }

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

  // render title in small caps with a rule, then author | date (from document metadata)
  show title: it => {
    align(right, context {
      let t = smallcaps(text(weight: "regular", it))
      t
      line(
        length: measure(t).width,
        stroke: 0.5pt,
      )
      set text(size: 11pt, weight: "regular")

      let parts = ()
      let author = document.author.join(", ")
      if author != none {
        parts.push(author)
      }

      if document.date != none {
        let format = "[month repr:long] [day], [year]"
        parts.push(document.date.display(format))
      }

      if document.description != none {
        parts.push(document.description)
      }

      parts.join(parbreak())
    })
    v(1em)
  }

  // tables
  set table(stroke: (x, y) => (
    left: if x > 0 { 0.5pt } else { 0pt },
    bottom: if y == 0 { 0.5pt } else { 0pt },
  ))

  // figures
  set figure(gap: 2em, placement: top)
  // space between floating figures and the body text (default 1.5em)
  set place(clearance: 2.5em)
  // inset captions by 1em per side; center single-line captions,
  // otherwise justify with a flush-left last line
  show figure.caption: it => {
    let caption = {
      smallcaps[#it.supplement #context it.counter.display(it.numbering)]
      it.separator
      it.body
    }
    pad(x: 1em, layout(size => {
      if measure(caption).width <= size.width { align(center, caption) } else { align(left, caption) }
    }))
  }

  // citations
  set bibliography(style: "chicago-author-date")

  body
}
