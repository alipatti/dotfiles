from pathlib import Path

import pytest

from pdf2md.steps.degarble import degarble, peel, to_latex

# garbled lines and their degarbled versions
CONVERSIONS: list[tuple[str, str]] = [
    (
        "the estimator θ<sup>∗</sup> <sub>n</sub> converges",
        r"the estimator $\theta^{*}_{n}$ converges",
    ),
    (
        "where x<sub>i</sub> ∈ ℝ<sup>d</sup>, and",
        r"where $x_{i} \in \mathbb{R}^{d}$, and",
    ),
    ("for all α ≤ 0.05.", r"for all $\alpha \leq 0.05$."),
    ("as n → ∞ we have", r"as $n \rightarrow \infty$ we have"),
    ("the (see θ) case", r"the (see $\theta$) case"),
    ("f(θ, x) = 0 holds", r"$f(\theta, x) = 0$ holds"),
    ("αx and Σ", r"$\alpha x$ and $\Sigma$"),
    ("x′ and θ∗", r"$x'$ and $\theta*$"),
    ("𝜃 ∈ 𝒩", r"$\theta \in \mathcal{N}$"),
    ("[about θ](https://example.com/θ)", r"[about $\theta$](https://example.com/θ)"),
    ("a θ is a σ", r"a $\theta$ is a $\sigma$"),
    # spacing accents go on the next symbol, combining ones on the previous
    ("estimate ˆθ here", r"estimate $\hat{\theta}$ here"),
    ("estimate θ̂ here", r"estimate $\hat{\theta}$ here"),
    ("the mean x̄ is", r"the mean $\bar{x}$ is"),
    ("and C˜ is", r"and $\tilde{C}$ is"),
    # pdftotext puts accents that latex draws as separate glyphs after a space or
    # punctuation
    ("the estimate 𝜃 ̂ is", r"the estimate $\hat{\theta}$ is"),
    ("close to 𝜃,̃ and", r"close to $\tilde{\theta}$, and"),
    ("the mean is 𝑥.̄", r"the mean is $\bar{x}$."),
    # old latex fonts extract ≠ as 6=
    ("whenever x 6= 0", r"whenever $x \neq 0$"),
    ("the set A ∩ B 6= ∅", r"the set $A \cap B \neq \emptyset$"),
    # spans with characters that have no LaTeX are left for the LLM steps
    ("θ€ and α", r"θ€ and $\alpha$"),
]
# lines that are already fine
CLEAN: list[str] = [
    "plain prose without math.",
    "a footnote.[<sup>1</sup>](#fn1)",
    r"costs \$5 and $\theta$ is fine",
    r"inline $\alpha \leq \beta$ and display $$\sum_{i} x_{i}^{2}$$ math",
    "temperatures of −5 degrees",
    # 6= that is arithmetic rather than ≠
    "so 2 + 6 = 8",
    "so 2 + 6= 8",
    "so x+6=8",
    "so 16= 4 times 4",
    "and 6=6",
    "the total is 3 × 6= 18",
    "so 1 + 6 != 7",
    "so 1 + 6!= 7",
    "<span id='page-1-0'></span>",
    # the round trip snippets, which are correctly formatted markdown
    *(
        line
        for snippet in sorted((Path(__file__).parent / "roundtrip").glob("*.md"))
        for line in snippet.read_text().splitlines()
    ),
]


@pytest.mark.parametrize(("line", "expected"), CONVERSIONS)
def test_converts_garbled_math(line: str, expected: str) -> None:
    """Rewrite runs of garbled math as LaTeX, leaving the prose around them."""
    assert degarble(line) == expected


@pytest.mark.parametrize("line", CLEAN + [expected for _, expected in CONVERSIONS])
def test_leaves_clean_lines(line: str) -> None:
    """Leave prose, latex (including its own output), links, and footnotes alone."""
    assert degarble(line) == line


@pytest.mark.parametrize("line", [line for line, _ in CONVERSIONS] + CLEAN)
def test_idempotent(line: str) -> None:
    """Degarbling twice is the same as degarbling once."""
    once = degarble(line)
    assert degarble(once) == once


@pytest.mark.parametrize("text", ["θ€", "<sub>θ€</sub>", "x ˆ"])
def test_to_latex_gives_up(text: str) -> None:
    """Return None for unknown characters, including in scripts and after accents."""
    assert to_latex(text) is None


@pytest.mark.parametrize(
    ("span", "expected"),
    [
        ("θ,", ("", "θ", ",")),
        ("θ).", ("", "θ", ").")),
        ("(θ", ("(", "θ", "")),
        ("(θ)", ("", "(θ)", "")),
        ("f(θ)", ("", "f(θ)", "")),
    ],
)
def test_peel(span: str, expected: tuple[str, str, str]) -> None:
    """Split off trailing punctuation and unmatched brackets, keeping matched ones."""
    assert peel(span) == expected
