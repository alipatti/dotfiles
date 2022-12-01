\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{cribsheet}

\LoadClass{article}
\usepackage{macros}  % load user macros/base configuration


% PAGE SETUP
\geometry{margin=1cm}
\twocolumn
\setlength{\columnsep}{1cm}


% SECTION FORMATTING
\RequirePackage[explicit]{titlesec}
\usepackage{xhfill}
\titleformat{\subsection}  % subsection formatting 
  {\scshape \normalsize} % before
  {}
  {0em}  % number-header spacing 
  {#1}
  [\vspace{-1em}\xhrulefill{lightgray}{.5pt}]  % after

\titleformat{\section}  % section formatting
  {}
  {}
  {0em}  % number-header spacing 
  {\Large \bfseries
   \xrfill[.2em]{.5pt}~#1~\xrfill[.2em]{.5pt}}

\titlespacing{\section}
  {0em}  % leading
  {2em}  % before
  {1em}  % after


% LIST STYLING
\setlist{
  topsep=-.1em,
  itemsep=0em,
}
\setlist[enumerate]{
  leftmargin=3em,
  label=(\roman*),
}
\setlist[itemize]{
  leftmargin=1.5em,
  label=-,
}


% HEADER/FOOTER
\usepackage{fancyhdr}
\pagestyle{fancy}  % show header
\fancyhfinit{\scriptsize \itshape}  % change font
\renewcommand{\headrulewidth}{0pt}  % remove line
\fancyhf{}
\setlength{\footskip}{.4cm}
\cfoot{Alistair Pattison}

% THEOREM ENV.
\newtheorem{theorem}{Theorem}
