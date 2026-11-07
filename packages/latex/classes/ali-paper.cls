\ProvidesClass{ali-paper}

% declare options
\RequirePackage{kvoptions}
\SetupKeyvalOptions{
	family=option,
	prefix=option@
}

\DeclareBoolOption[false]{theorems}
\DeclareBoolOption[false]{tables}
\DeclareBoolOption[false]{bib}
\DeclareBoolOption[false]{pgf}
\DeclareBoolOption[true]{titles}
\DeclareBoolOption[true]{refs}
\ProcessKeyvalOptions*

\LoadClass[10pt]{article}

% misc standard packages
\RequirePackage[margin=1in]{geometry} % set margins
\RequirePackage{fancyhdr} % add a header to each page
\RequirePackage{xcolor} % colored text
\RequirePackage{parskip} % space between paragraphs + no indentation
\RequirePackage{graphicx} % insert external graphics
\RequirePackage{pdflscape} % rotate pages for wide figures/tables

% place tables and figures at top of page by default
% \RequirePackage{float}
% \floatplacement{figure}{t}
% \floatplacement{table}{t}

% theorem environments
\ifoption@theorems
	\RequirePackage{amsthm}
	\RequirePackage{thmtools}

	% --- primary environments ---
	\declaretheorem{theorem}
	\declaretheorem[sibling=theorem]{definition, conjecture, corollary, lemma, example, remark, claim, proposition}
\fi

% biblatex setup
\ifoption@bib
	\RequirePackage[
		style=authoryear,
		maxbibnames=20,
		maxcitenames=3,
		url=false
	]{biblatex}
\fi

\ifoption@refs
	\AtEndPreamble{
		% links and references within the document
		\RequirePackage{hyperref}
		\hypersetup{
			unicode=true,
			pdfusetitle,
			hidelinks,
		}

		% automatically prepend "Figure" / "Table" to references
		% https://tug.ctan.org/macros/latex/contrib/cleveref/cleveref.pdf
		\RequirePackage[nameinlink, noabbrev, capitalise]{cleveref}
		\crefname{equation}{equation}{equations}
		\crefname{appendix}{Appendix}{Appendices}
		\Crefname{appendix}{Appendix}{Appendices}

		% number equations within their appendix section, e.g. Equation C.12
		\numberwithin{equation}{section}
	}
\fi

% section and title formatting
\ifoption@titles
	\renewcommand{\maketitle}{
		\begin{center}
			{\LARGE \scshape \@title}

			\vspace{-.5em}
			\rule{.4 \textwidth}{0.5pt}

			{\@author \hspace{.4em} $|$ \hspace{.4em} \@date}
		\end{center}
	}

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

\ifoption@tables
	% table/figure formatting
	\RequirePackage{booktabs} % nicer looking tables
	\RequirePackage{makecell} % adds ability to have line breaks inside cells
	\RequirePackage{subcaption} % panels in figures
	\RequirePackage{pgf}

	% load data from csvs
	\RequirePackage{csvsimple-l3}
	\csvstyle{every csv}{
		head to column names,
	}
\fi

\ifoption@pgf
	\usepackage{pgf}
	\usepackage{tikz}
	\usepackage{pgfplots}
\fi

% redefine caption formats
\usepackage{caption}

\captionsetup{
	labelfont=sc,
	justification=centering,
	tablename=Table,
	figurename=Figure,
}

\captionsetup[subfigure]{
	labelformat=simple,
	labelsep=period,
	font={singlespacing}
}

\newcommand{\notes}[1]{
	\begin{quote}
		\itshape
		{\scshape Notes}: #1
	\end{quote}
}

% TOC only goes to sections
\setcounter{tocdepth}{1}

% list formatting
\RequirePackage{enumitem}
% \setlist[enumerate,1]{label=(\roman*)}

% appendix customization
\let\oldappendix\appendix
\renewcommand{\appendix}{%
	\clearpage

	% make pages numbered e.g. A-1
	\pagenumbering{arabic}
	\renewcommand{\thepage}{A-\arabic{page}}

	% reset figure numbering back to zero and prepend "A.", e.g. Figure A.12
	\setcounter{table}{0}
	\setcounter{figure}{0}
	\renewcommand{\thetable}{A.\arabic{table}}
	\renewcommand{\thefigure}{A.\arabic{figure}}

	% cleveref: make sections get referenced as “Appendix”
	\crefalias{section}{appendix}
	\crefalias{subsection}{appendix}
	\crefalias{subsubsection}{appendix}

	\oldappendix
}

