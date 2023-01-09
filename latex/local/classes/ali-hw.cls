\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{ali-hw}

\LoadClass{article}
\RequirePackage{ali-macros, ali-lists, ali-spacing, ali-theorems, ali-links, ali-headings}

% ------------------
% SECTION FORMATTING
% ------------------

\def\problem{\subsection*}
\renewcommand{\part}[1]{\MakeUppercase{\textbf{#1.}}}

% -----------------
% FOOTER FORMATTING
% -----------------

% \RequirePackage{fancyhdr}
% \pagestyle{fancy}
% \fancyhf{} % sets both header and footer to nothing
% \renewcommand{\headrulewidth}{0pt}  % remove header line
