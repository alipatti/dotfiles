\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{ali-cribsheet}

\LoadClass{article}
\usepackage{ali-macros}  % load user macros/base configuration

% PAGE SETUP
\RequirePackage{parskip}
\RequirePackage{geometry}
\geometry{margin=.5in, bottom=.75in}
\twocolumn
\setlength{\columnsep}{.5in}

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
\RequirePackage{enumitem}
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
\setlength{\footskip}{.375in}
\cfoot{\@title{} — \@author{} — \@date}

% THEOREM ENVS
\RequirePackage{amsthm}
\newtheorem*{definition}{Df}
\newtheorem*{example}{Ex}
\newtheorem*{theorem}{Th}
