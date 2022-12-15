\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{homework}

\LoadClass{article}

% TITLE FORMATTING
\makeatletter
\renewcommand{\maketitle}{
    {\Huge \scshape \@title}

    {\@date} \hfill {\@author}
}
\makeatother

% TODO move this to styles.sty
% SECTION FORMATTING
\RequirePackage{titlesec}

\titleformat{\section}
    {\Large\bfseries}
    {}{.5em}
    {}
    [\vspace{.5em}\hrule]
\titlespacing{\section}{-.8em}{2pc}{1pc}

\newcounter{problem}
\titleformat{\subsection}[leftmargin]
    {\vspace{10pt}\bfseries\filleft}
    {\thesubsection}{.5em}
    {\addtocounter{problem}{1}}
\titlespacing{\subsection}{4pc}{1.5ex plus .1ex minus .2ex}{1pc}

\def\problem{\subsection*}
\renewcommand{\part}[1]{
    
\MakeUppercase{\textbf{#1.}}}

% HEADER FORMATTING
\RequirePackage{fancyhdr}
\pagestyle{fancy}
\rhead{Alistair Pattison}

% MATH PACKAGES
\RequirePackage{amssymb,amsmath,amsthm}
\RequirePackage{bbm} % \mathbb for numbers
\RequirePackage{mathtools}

% THEOREM ENVIRONMENTS
\newtheorem{claim}{Claim}
\newtheorem{definition}{Definition}

% LINKING
\RequirePackage[colorlinks]{hyperref}

% GRAPHICS PACKAGES
\RequirePackage{graphicx}

% TIKZ
\RequirePackage{tikz}
\usetikzlibrary{
    positioning,
    graphs, graphs.standard,
    arrows,
    calc,
    trees, braids,
    quantikz
}

\RequirePackage{minted}
\setminted{autogobble}

% ARRAY/TABLE FORMATTING
\RequirePackage{array}
\def\arraystretch{1.3}

% LOAD MACROS
\RequirePackage{macros}