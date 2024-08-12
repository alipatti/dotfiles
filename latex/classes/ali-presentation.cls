\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{ali-presentation}
\LoadClass{beamer}

\RequirePackage[utf8]{inputenc}
\RequirePackage{ali-macros}

% --- COLORS --- %

% minnesota
\xdefinecolor{umn-maroon}{HTML}{7A0019}
\xdefinecolor{umn-maroon-dark}{HTML}{5B0013}
\xdefinecolor{umn-gold}{HTML}{FFCC33}
\xdefinecolor{umn-gold-dark}{HTML}{FFB71E}
\xdefinecolor{umn-gold-light}{HTML}{FFDE7A}

% carleton
\xdefinecolor{carleton-blue}{HTML}{003E7E}
\xdefinecolor{carleton-blue-light}{HTML}{2D538F}
\xdefinecolor{carleton-maize}{HTML}{FFD24F}
\xdefinecolor{carleton-maize-dark}{HTML}{EEB111}
\xdefinecolor{carleton-maize-light}{HTML}{FFEFC8}

% opportunity insights
\xdefinecolor{oi-green}{HTML}{29B6A4}
\xdefinecolor{oi-darkcyan}{HTML}{1B7372}

% --- CLASS OPTIONS --- %

\DeclareOption{umn}{
	\colorlet{primaryColor}{umn-maroon}
	\colorlet{secondaryColor}{umn-gold}
	\def\logo{\includegraphics{logo_umn.png}}
}

\DeclareOption{carleton}{
	\colorlet{primaryColor}{carleton-blue}
	\colorlet{secondaryColor}{carleton-maize}
	\def\logo{\includegraphics{logo_carleton.png}}
}

\DeclareOption{oi}{
	\colorlet{primaryColor}{oi-green}
	\colorlet{secondaryColor}{oi-darkcyan}
	\def\logo{\includegraphics{oi.png}}
}

% defaults
\colorlet{primaryColor}{carleton-blue}
\colorlet{secondaryColor}{carleton-maize}
\def\logo{\color{white}x}

\newif\if@ali@memey
\DeclareOption{memey}{\@ali@memeytrue}

%%%%%%%%%%
% BEAMER %
%%%%%%%%%%

% pass all other class options to beamer
\DeclareOption*{\PassOptionsToClass{\CurrentOption}{beamer}}
\ProcessOptions\relax

% hide navigation symbols
\setbeamertemplate{navigation symbols}{}

% lists
\setbeamertemplate{itemize item}{\textbullet}
\setbeamertemplate{itemize subitem}{-}
\setbeamertemplate{itemize subsubitem}{-}
\setbeamertemplate{enumerate items}[default]
\setbeamertemplate{sections/subsections in toc}[sections numbered]

% COLORS
\setbeamercolor{structure}{fg=primaryColor}

\addtobeamertemplate{block begin}{}{
	\vspace{4pt} {\color{primaryColor!40!white} \hrule} \vspace{1em}
}

% FONTS
\RequirePackage{fontspec}
\usefonttheme[onlymath]{serif}

\setbeamerfont{date}{size=\footnotesize}
\setbeamerfont{author}{size=\footnotesize}
\setbeamerfont{subtitle}{series=\normalfont}
\setbeamerfont{framesubtitle}{series=\normalfont}

\if@ali@memey
	\setsansfont{Comic Sans MS}
	\usefonttheme{structurebold}
\else
	\setsansfont{Trebuchet MS}
	% \usefonttheme{structuresmallcapsserif}
\fi

% FOOTER 
\setbeamertemplate{footline}{
	\parbox{\textwidth}{
		\hspace{1em}
		\resizebox{!}{3em}{\logo}
		\hfill
		\color{gray}\tiny
		\insertframenumber\,/\,\inserttotalframenumber
		\hspace{1em}

		\vspace{1em}
	}
}

% FRAME TITLE
\addtobeamertemplate{frametitle}{\vspace*{1em}}{\vspace*{.5em}}

\setbeamersize{
	sidebar width left=1em,
	sidebar width right=1em,
	% 	text margin right=3em,
	% 	text margin left=3em,
}
