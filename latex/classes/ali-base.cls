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

\newif\if@ali@lists
\@ali@liststrue
\DeclareOption{nolists}{\@ali@listsfalse}

\newif\if@ali@spacing
\@ali@spacingtrue
\DeclareOption{nospacing}{\@ali@spacingfalse}

\newif\if@ali@math
\DeclareOption{math}{\@ali@mathtrue}

\newif\if@ali@theorems
\DeclareOption{theorems}{\@ali@theoremstrue}

\newif\if@ali@pseudocode
\DeclareOption{pseudocode}{\@ali@pseudocodetrue}

\newif\if@ali@minted
\DeclareOption{minted}{\@ali@mintedtrue}

% pass remaining options to article class
\DeclareOption*{\PassOptionsToClass{\CurrentOption}{article}}
\ProcessOptions\relax
\LoadClass{article}

% --- DO THINGS THAT SHOULD ALWAYS HAPPEN --- %

% packages that should always get loaded
\RequirePackage[colorlinks]{hyperref}
\RequirePackage{amsmath, amssymb}

% fix greek letters because i'm not a psychopath
\let\oldphi\phi
\let\phi\varphi
\let\varphi\oldphi

\let\oldepsilon\epsilon
\let\epsilon\varepsilon
\let\varepsilon\oldepsilon

% --- PROCESS PACKAGE OPTIONS --- %

\if@ali@titlepage
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
	\declaretheorem{claim}

	\declaretheorem{theorem}
	\declaretheorem[sibling=theorem]{definition, conjecture}

	% --- secondary environments --- 
	\declaretheoremstyle[
		headfont=\itshape\bfseries,
		notefont=\itshape\mdseries,
		notebraces={(}{)},
		bodyfont=\normalfont,
	]{secondary}

	\declaretheorem[
		style=secondary,
		sibling=theorem,
	]{lemma, corollary, example, remark}
\fi

\if@ali@math
	\RequirePackage{mathtools} % does a bunch of stuff
	\RequirePackage{xfrac}  % inline slanted fractions with \sfrac
	\RequirePackage{eucal} % nicer-looking \mathcal
	\RequirePackage{mathrsfs}  % add mathscr (script)

	% bracket pairs
	\newcommand{\set}[1]{\left\{ #1 \right\}}
	\newcommand{\tuple}[1]{\left\langle #1 \right\rangle}
	\newcommand{\paren}[1]{\left( #1 \right)}
	\newcommand{\ceil}[1]{\left\lceil #1 \right\rceil}
	\newcommand{\floor}[1]{\left\lfloor #1 \right\rfloor}
	\newcommand{\abs}[1]{\left| #1 \right|}
	\newcommand{\norm}[1]{\left\| #1 \right\|}
	\newcommand{\inner}[2]{\left\langle #1 , #2 \right\rangle}

	% left maps to arrow: <-|
	\newcommand{\mapsfrom}{\mathbin{\scalebox{-1}[1]{\mapsto}}}

	% common sets
	\newcommand{\Z}{\mathbb Z}  % integers
	\newcommand{\R}{\mathbb R}  % reals
	\newcommand{\Q}{\mathbb Q}  % rationals
	\newcommand{\C}{\mathbb C}  % complexes
	\newcommand{\N}{\mathbb N}  % naturals
	\newcommand{\T}{\mathbb T}  % circle group
	\newcommand{\A}{\mathbb A}  % algebraic integers
	\newcommand{\F}{\mathbb F}  % finite field
	% \newcommand{\S}{\mathcal{S}} % symetric group
	\newcommand{\bit}{\set{0,1}}  % bits

	% function groups, etc.
	\DeclareMathOperator{\Hom}{Hom} % homomorphisms
	\DeclareMathOperator{\Aut}{Aut} % automorphisms
	\DeclareMathOperator{\Gal}{Gal} % Galois group
	\DeclareMathOperator{\Fix}{Fix} % Fixed field
	\DeclareMathOperator{\End}{End} % endomorphism
	\DeclareMathOperator{\Sym}{Sym}
	\DeclareMathOperator{\Frac}{Frac} % fraction field
	\DeclareMathOperator{\Stab}{Stab} % stabilizer

	% groups
	\DeclareMathOperator{\GL}{GL}
	\DeclareMathOperator{\SL}{SL}
	\DeclareMathOperator{\M}{M}
	\DeclareMathOperator{\SO}{SO}
	\DeclareMathOperator{\SU}{SU}
	\DeclareMathOperator{\U}{U}

	% misc operations
	\DeclareMathOperator*{\argmin}{arg\,min}  % argmin
	\DeclareMathOperator*{\argmax}{arg\,max}  % argmax
	\DeclareMathOperator*{\med}{median}  % median
	\DeclareMathOperator*{\sign}{sign}  % sign
	\DeclareMathOperator*{\lcm}{lcm}  % lcm
	\DeclareMathOperator*{\supp}{supp}  % support
	\DeclareMathOperator*{\Li}{Li}
	\newcommand{\given}{\mid}
	\newcommand{\divides}{\mid}
	\newcommand{\concat}{\mid}
	\newcommand{\tensor}{\otimes}  % tensor product
	\newcommand{\tensorpower}[1]{^{\tensor #1}}  % tensor power
	\newcommand{\conj}{\overline}  % complex conjugate
	\newcommand{\cross}{\times}  % cross product
	\newcommand{\of}{\circ}  % function composition
	\newcommand{\quotient}[1]{\, \big/ \, #1} % quotient groups
	\newcommand{\iso}{\cong} % isomorphic
	\newcommand{\normal}{\lhd} % normal subgroup

	\newcommand{\dual}{\widetilde}

	% frequent text
	\newcommand{\id}{{\mathrm{id}}} % identity
	\newcommand{\squarefree}{\ \text{$\square$-free}}
	\newcommand{\otherwise}{\text{otherwise}}
	\renewcommand{\and}{\text{and}}

	% common exponents
	\newcommand{\inv}{^{-1}}  % inversion
	\newcommand{\trans}{^T} % transpose
	\renewcommand{\perp}{^\bot} % perp
	\renewcommand{\star}{^*} % star
	\newcommand{\units}{^\times}

	% image, rank, span, trace, etc.
	\DeclareMathOperator{\im}{im}
	\DeclareMathOperator{\rank}{rank}
	\DeclareMathOperator{\spn}{span}  % \span is a built-in latex command
	\DeclareMathOperator{\tr}{tr}
	\DeclareMathOperator{\adj}{adj}
	\DeclareMathOperator{\chr}{char} % \char is built in

	% different equals signs
	\RequirePackage{mathtools}
	\newcommand{\ceq}{\coloneqq} % definition
	\newcommand{\qeq}{\overset ? =} % maybe equal

	% fixing \Re, \Im
	\DeclareMathOperator{\Real}{Re}
	\DeclareMathOperator{\Imag}{Im}

	% stats/probability stuff
	\newcommand{\prob}[1]{{\mathrm P}\paren{#1}}
	\newcommand{\expec}[1]{{\mathrm E}\paren{#1}}
	\DeclareMathOperator*{\var}{var}
	\DeclareMathOperator*{\Bias}{Bias}
	\DeclareMathOperator*{\MSE}{MSE}
	\DeclareMathOperator{\Norm}{Norm}
	\DeclareMathOperator{\Gam}{Gamma}
	\DeclareMathOperator{\Binom}{Binom}
	\DeclareMathOperator{\logit}{logit}

	% crypto stuff
	\newcommand{\Enc}{\Call{Enc}{}}
	\newcommand{\Dec}{\Call{Dec}{}}
	\newcommand{\Sign}{\Call{Sign}{}}
	\newcommand{\KeyGen}{\Call{KeyGen}{}}
	\newcommand{\Eav}{\Call{Eav}{}}
	\newcommand{\linkedwith}{\: \vcenter{\hbox{\text{\footnotesize$\diamondsuit$}}}\: }
	\renewcommand{\L}{\mathcal L}

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
