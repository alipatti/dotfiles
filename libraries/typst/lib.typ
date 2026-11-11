// theorems (re-exported: theorem, definition, corollary, proof, ...)
#import "@preview/theorion:0.6.0": *
#import cosmos.rainbow: *

// figures and diagrams (re-exported)
#import "@preview/subpar:0.2.2"
#import "@preview/cetz:0.4.2": canvas, draw
#import "@preview/fletcher:0.5.8" as fletcher: diagram, edge, node

// grow nested delimiters by depth
#import "nested-delims.typ": nested-delims

// space relations in display math
#import "relation-spacing.typ": relation-spacing

// tables from csv data
#import "format.typ": format-num
#import "tables.typ": make-table

// single values from csv data
#import "data.typ": find-row, format-cell

// macros
#let todo(x) = "TODO: " + x
#let inner(x, y) = $chevron.l #x, #y chevron.r$
#let to = $arrow.r$
#let of = $med circle.small med$
#let toto = $arrows.rr$
#let End = $op("End")$
#let poly = $op("poly")$
#let var = $op("var")$
#let cov = $op("cov")$
#let st = $op("s.t.")$

// probability and convergence
#let pto = $stretch(arrow.r)^p$
#let dto = $stretch(arrow.r)^d$
#let asto = $stretch(arrow.r)^"a.s."$
#let qmto = $stretch(arrow.r)^2$
#let iid = $attach(~, t: "i.i.d.")$
#let ind = $bb(1)$
#let supp = $op("supp")$
#let argmax = $op("arg" thin "max", limits: #true)$

#let tcite(key, ..args) = cite(key, form: "prose", ..args)

// equivalent of latex's \clearpage: place pending floats, then start a new page
#let clearpage() = {
  place.flush()
  pagebreak(weak: true)
}

// start the appendices on a new page: letter headings from A and reference them as
// "Appendix A", and number figures and tables afresh as A1, A2, ...
// applied to the rest of the document with `#show: ali.appendix`
#let appendix(body) = {
  clearpage()
  counter(heading).update(0)
  counter(figure.where(kind: image)).update(0)
  counter(figure.where(kind: table)).update(0)
  set heading(numbering: "A.1", supplement: [Appendix])
  set figure(numbering: n => "A" + str(n))
  body
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
  // term lists as hanging paragraphs: "_term_. description" with wrapped lines indented
  show terms: it => context {
    let spacing = if it.spacing != auto { it.spacing } else if it.tight { par.leading } else { par.spacing }
    set par(spacing: spacing)
    block(inset: (left: 1em), it.children.map(item => par(hanging-indent: 1.5em, emph(item.term) + [. ] + item.description)).join())
  }
  set par(justify: true, leading: 0.6em, first-line-indent: 0em, spacing: 1em)

  // extra space around relations in display math
  show: relation-spacing

  // numbering
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
  // space around inline figures, which otherwise get only paragraph spacing
  show figure: set block(spacing: 2em)
  // number images and tables in one sequence (figure 1, table 2, ...)
  // by stepping the other kind's counter alongside each figure
  show figure.where(kind: image): it => counter(figure.where(kind: table)).step() + it
  show figure.where(kind: table): it => counter(figure.where(kind: image)).step() + it
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
