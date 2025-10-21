\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{ali-base}

% --- DECLARE PACKAGE OPTIONS --- %

\newif\if@ali@titlepage
\DeclareOption{titlepage}{\@ali@titlepagetrue}

\newif\if@ali@title
\@ali@titletrue
\DeclareOption{notitle}{\@ali@titlefalse}

\newif\if@ali@sections
\@ali@sectionstrue
\DeclareOption{nosections}{\@ali@sectionsfalse}

\newif\if@ali@partnewpage
\DeclareOption{partnewpage}{\@ali@partnewpagetrue}

\newif\if@ali@lists
\@ali@liststrue
\DeclareOption{nolists}{\@ali@listsfalse}

\newif\if@ali@spacing
\@ali@spacingtrue
\DeclareOption{nospacing}{\@ali@spacingfalse}

\newif\if@ali@theorems
\DeclareOption{theorems}{\@ali@theoremstrue}

\newif\if@ali@listoftheorems
\DeclareOption{listoftheorems}{\@ali@listoftheoremstrue}

\newif\if@ali@pseudocode
\DeclareOption{pseudocode}{\@ali@pseudocodetrue}

\newif\if@ali@minted
\DeclareOption{minted}{\@ali@mintedtrue}

% pass remaining options to article class
\DeclareOption*{\PassOptionsToClass{\CurrentOption}{article}}
\ProcessOptions\relax
\LoadClass{article}

% --- DO THINGS THAT SHOULD ALWAYS HAPPEN --- %

\RequirePackage[colorlinks]{hyperref}
\RequirePackage{ali-macros}
\RequirePackage{ali-todo}

% --- PROCESS PACKAGE OPTIONS --- %

\if@ali@titlepage
	\RequirePackage{tocloft}

	% title on separate page
	\renewcommand{\maketitle}{
		\begin{titlepage}
			\null \vspace{1.5in}

			\begin{center}
				{\LARGE \scshape \@title}

				\rule{.4 \textwidth}{0.5pt}

				{\scshape \large \@author}

				\@date

				\vspace{1in}

				\begin{minipage}{4in}
					\renewcommand{\cftsecleader}{\cftdotfill{\cftdotsep}}
					\renewcommand*\l@section{\@dottedtocline{1}{.75em}{1.5em}}
					% \setlength{\cftpartafterpnum}{.5em}
					\tableofcontents
				\end{minipage}
			\end{center}
		\end{titlepage}
	}
\else
	\renewcommand{\maketitle}{
		\begin{center}
			{\LARGE \scshape \@title}

			\vspace{-.5em}
			\rule{.4 \textwidth}{0.5pt}

			{\@author \hspace{.4em} $|$ \hspace{.4em} \@date}
		\end{center}
	}
\fi

\if@ali@sections
	\RequirePackage{titlesec}

	\titleformat{\part}
	{\huge\scshape\centering}
	{\thepart}
	{.7em}
	{}

	\titleformat{\section}
	{\Large\scshape\centering}
	{\thesection}
	{.7em}
	{}

	\titleformat{\subsection}
	{\large\scshape}
	{\thesubsection}
	{.7em}
	{}

	\titleformat{\subsubsection}[runin]
	{\normalfont\normalsize\scshape}
	{}
	{0em}
	{}
	[.]
\fi

\if@ali@partnewpage
	\AddToHook{cmd/part/before}{\clearpage}
\fi

\if@ali@lists
	\RequirePackage{enumitem}

	\setlist[enumerate]{
		label=(\roman*),
	}

	\setlist[itemize]{
		label=-,
	}
\fi

\if@ali@spacing
	\RequirePackage[margin=1.3in]{geometry}
	\RequirePackage{parskip}

	% ARRAY/TABLE FORMATTING
	\RequirePackage{array}
	\def\arraystretch{1.3}

	\setlength{\jot}{1em} % give extra space in multiline equation

	% redefine \hrule
	% https://tex.stackexchange.com/questions/128636/center-hrule-in-the-middle-of-the-page
	\newcommand{\divider}{
		\begin{center}
			\bigskip
			\rule{.2 \textwidth}{0.5pt}
			% \scalebox{6}[1.2]{$\sim$}
			\bigskip
		\end{center}
	}
\fi

\if@ali@theorems
	\RequirePackage{amsthm}
	\RequirePackage{thmtools}

	% --- primary environments ---
	\declaretheorem{theorem}
	\declaretheorem[sibling=theorem]{definition, conjecture, corollary, lemma, example, remark, claim, proposition}
\fi

\if@ali@listoftheorems
	\AtEndDocument{
		\appendix

		\clearpage
		\phantomsection
		\addcontentsline{toc}{section}{\listtheoremname}
		\listoftheorems[
			ignoreall,
			show={definition,theorem,conjecture},
		]

		\phantomsection
		\addcontentsline{toc}{section}{\listfigurename}
		\listoffigures

		\phantomsection
		\addcontentsline{toc}{section}{\listtablename}
		\listoftables
	}
\fi

\if@ali@pseudocode
	\RequirePackage[
		noEnd,
		endLComment={},
	]{algpseudocodex}

	\RequirePackage{algorithm}
	\newcommand{\algorithmautorefname}{Algorithm}

	\newcommand{\function}[3]{
		\Function {#1} {#2}
		#3
		\EndFunction
		\smallskip
	}

	% for approximation algorithms
	\RequirePackage{xspace}  % proper spacing after macros
	\def\opt{\texttt{OPT}\xspace}
	\def\greedy{\texttt{GREEDY}\xspace}
	\def\round{\texttt{ROUND}\xspace}
\fi

\if@ali@minted
	\RequirePackage{minted}
	\setminted{autogobble}
\fi
