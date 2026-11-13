import re
from dataclasses import dataclass
from importlib.metadata import version
from itertools import zip_longest
from pathlib import Path

from docutils.utils.math.unichar2tex import uni2tex_table

from pdf2md.document import PROTECTED_SPANS, Document, is_garbled
from pdf2md.steps.base import Step, StepResult

# docutils' table of unicode math characters and their LaTeX commands, which end in a
# space so they don't run into a following letter. primes and asterisks read better as
# ascii, which also works in superscripts
SYMBOLS: dict[str, str] = {
    **{chr(code): latex for code, latex in uni2tex_table.items()},
    "∗": "*",
    "′": "'",
    "″": "''",
    "·": r"\cdot ",
    "{": r"\{",
    "}": r"\}",
}
# combining accents follow the letter they go on. spacing ones come before it, or after
# it at the end of a word
COMBINING_ACCENTS: dict[str, str] = {
    "\u0302": "hat",
    "\u0303": "tilde",
    "\u0304": "bar",
    "\u0305": "bar",
    "\u0307": "dot",
    "\u0308": "ddot",
    "\u20d7": "vec",
}
SPACING_ACCENTS: dict[str, str] = {"ˆ": "hat", "˜": "tilde", "¯": "bar", "˙": "dot"}
# a combining accent that pdftotext put after a space or punctuation, since the pdf
# positions it over its letter as a separate glyph (as latex's unicode-math does)
DETACHED_ACCENT = re.compile(rf"([^\s.,;:])([\s.,;:]+)([{''.join(COMBINING_ACCENTS)}])")

# characters that mean the same in math as in prose
PLAIN = re.compile(r"[A-Za-z0-9 +\-=/()\[\],.;:!'<>*]")
# markdown escapes, which aren't needed in math, and emphasis, which marker puts on
# variables
ESCAPE = re.compile(r"\\([\\*_\[\]()<>#])")
EMPHASIS = re.compile(r"(?<!\\)\*")
# list, quote, and heading markers
BLOCK_PREFIX = re.compile(r"^(?:\s*(?:[-+*>]|\d+[.)]|#+)\s)*")
# how pdfs made with old latex fonts write ≠, as a word of its own. not after a number
# or operator, where it's more likely arithmetic, as in `2 + 6= 8`
NOT_EQUAL = re.compile(r"(?<![\d+\-−=*/×·<>]\s)(?<!\S)6=(?!\S)")
SCRIPT = re.compile(r"<(su[bp])>(.*?)</\1>")
# a word, keeping each sub/superscript whole even if it contains spaces
WORD = re.compile(r"(?:<(su[bp])>.*?</\1>|\S)+")
# words that can sit inside math but aren't evidence of it on their own: numbers,
# operators, and single letters (variables)
JOINER = re.compile(r"(?:[A-Za-z](?![A-Za-z])|[0-9+\-=/()\[\]{},.;:!'<>*−\\_])+")
# joiners that are usually english rather than variables (ignoring trailing punctuation)
ENGLISH = {"a", "I", "i.e", "e.g"}


@dataclass
class Degarble(Step):
    """Rewrite math that isn't LaTeX (html sub/superscripts, unicode symbols) as LaTeX.

    Rule-based, so it's free but only handles math whose structure survived conversion.
    Spans it can't convert are left as they are, for the LLM steps.
    """

    def key(self) -> dict:
        return super().key() | {"docutils": version("docutils")}

    def run(self, document: Document, out: Path) -> StepResult:
        markdown = "\n".join(map(degarble, document.lines)) + "\n"
        return StepResult(document=document.model_copy(update={"markdown": markdown}))


def degarble(line: str) -> str:
    """Wrap each run of garbled math in `line` in `$...$`, converted to LaTeX."""
    rest = BLOCK_PREFIX.sub("", line, count=1)
    prefix = line.removesuffix(rest)
    return prefix + "".join(
        degarble_text(text) + protected
        for text, protected in zip_longest(
            PROTECTED_SPANS.split(rest),
            PROTECTED_SPANS.findall(rest),
            fillvalue="",
        )
    )


def degarble_text(text: str) -> str:
    """`degarble` on text with no protected spans."""
    text = NOT_EQUAL.sub("≠", text)
    text = DETACHED_ACCENT.sub(lambda m: m[1] + m[3] + "".join(m[2].split()), text)
    words = list(WORD.finditer(text))
    result = []
    position = 0

    for run in math_runs(words):
        start, end = run[0].start(), run[-1].end()
        prefix, math, suffix = peel(text[start:end])
        latex = to_latex(math)

        if latex is not None:
            result += [text[position:start], prefix, f"${latex}$", suffix]
            position = end

    return "".join(result) + text[position:]


def math_runs(words: list[re.Match[str]]) -> list[list[re.Match[str]]]:
    """Maximal runs of math and joiner words that contain math, without english edges."""
    runs = []
    run = []

    for word in [*words, None]:
        if word and (is_math(word[0]) or JOINER.fullmatch(word[0])):
            run.append(word)
            continue

        while run and is_english(run[0][0]):
            run.pop(0)

        while run and is_english(run[-1][0]):
            run.pop()

        if any(is_math(w[0]) for w in run):
            runs.append(run)

        run = []

    return runs


def is_math(word: str) -> bool:
    """Whether a word is evidence of math, which a minus sign alone isn't."""
    return is_garbled(word) and not JOINER.fullmatch(word)


def is_english(word: str) -> bool:
    return word.rstrip(".,;:") in ENGLISH


def peel(span: str) -> tuple[str, str, str]:
    """Split trailing punctuation and unmatched brackets off a span of math."""
    prefix, suffix = "", ""

    while True:
        if span[-1] in ".,;:" or unmatched(span, -1):
            span, suffix = span[:-1], span[-1] + suffix
        elif unmatched(span, 0):
            span, prefix = span[1:], prefix + span[0]
        else:
            return prefix, span, suffix


def unmatched(span: str, index: int) -> bool:
    """Whether the bracket at `index` (the first or last character) has no partner."""
    pairs = {"(": ")", "[": "]", "{": "}"}
    pairs = pairs if index == 0 else {close: open for open, close in pairs.items()}
    char = span[index]
    return char in pairs and span.count(char) > span.count(pairs[char])


def to_latex(text: str) -> str | None:
    """The LaTeX for a span of garbled math, or None if it has unknown characters."""
    pieces: list[str] = []
    accent = None
    text = ESCAPE.sub(r"\1", EMPHASIS.sub("", text))
    i = 0

    while i < len(text):
        char = text[i]

        if script := SCRIPT.match(text, i):
            inner = to_latex(script[2])

            if inner is None:
                return None

            piece = f"{'_' if script[1] == 'sub' else '^'}{{{inner.strip()}}}"
            i = script.end()
        elif char in COMBINING_ACCENTS and pieces:
            pieces[-1] = rf"\{COMBINING_ACCENTS[char]}{{{pieces[-1].strip()}}}"
            i += 1
            continue
        elif char in SPACING_ACCENTS and text[i + 1 : i + 2].strip():
            accent = SPACING_ACCENTS[char]
            i += 1
            continue
        elif char in SPACING_ACCENTS and pieces and pieces[-1].strip():
            pieces[-1] = rf"\{SPACING_ACCENTS[char]}{{{pieces[-1].strip()}}}"
            i += 1
            continue
        elif char in SYMBOLS or PLAIN.fullmatch(char):
            piece = SYMBOLS.get(char, char)
            i += 1
        else:
            return None

        if accent and piece.strip():
            piece, accent = rf"\{accent}{{{piece.strip()}}} ", None

        pieces.append(piece)

    if accent:
        return None

    latex = re.sub(r"\s+", " ", "".join(pieces))
    return re.sub(r" (?=[_^,;.)\]'*])", "", latex).strip()
