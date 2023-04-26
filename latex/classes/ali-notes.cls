\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{ali-notes}

\LoadClass{article}

\RequirePackage{ali-lists}
\RequirePackage{ali-spacing}
\RequirePackage{ali-headings}
\RequirePackage{ali-theorems}
\RequirePackage[colorlinks]{hyperref}

% don't show subsections in TOC
\setcounter{tocdepth}{1}

% add new page at each part
\AddToHook{cmd/part/before}{\clearpage}

% add list of theorems, figures, etc. at the end of the notes
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
