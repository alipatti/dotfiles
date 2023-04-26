\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{ali-resume}

\LoadClass{article}

\RequirePackage{geometry}
\RequirePackage[explicit]{titlesec}
\RequirePackage{xhfill}
\RequirePackage{parskip}
\RequirePackage[colorlinks]{hyperref}
\RequirePackage{fontawesome}

% -- MARGINS --

\geometry{margin=.5in}
\pagestyle{empty}  % remove page numbering

% -- LISTS --

\RequirePackage{enumitem}

\setlist[itemize]{
	label={\bfseries-},
	leftmargin=1.5em,
	topsep=-.1em,
	itemsep=-.3em,
}

%  -- TITLE --
\makeatletter
\renewcommand{\maketitle}{
	\begin{center}
		{\Huge \scshape \@author}

		\vspace{-.5em}
		\rule{.4 \textwidth}{0.5pt}

		{\@title}
	\end{center}

}
\makeatother

% -- SECTION --

\titlespacing{\section}
{-1em}  % leading
{2em}  % before
{.6em}  % after

\titleformat{\section}
{}
{}
{0em}  % number-header spacing 
{\Large \bfseries  #1 \ \xrfill[.2em]{.5pt}}

% -- RESUME ITEM --

\titlespacing{\subsection}
{0em}  % leading
{1em}  % before
{.5em}  % after

\titleformat{\subsection}
{}
{}
{0em}  % number-header spacing 
{\textbf{\large #1}}

\newcommand{\resumeitem}[3]{\subsection{%
		#1, \normalfont
		\textit{#2}
		\hfill {\normalsize \itshape (#3)}
	}}

% -----------
% -- LINKS -- 
% -----------

\let\oldhref\href
\renewcommand{\href}[2]{%
	#2
	\oldhref{#1}{\raisebox{-.1em}{\faicon{link}}}%
}

