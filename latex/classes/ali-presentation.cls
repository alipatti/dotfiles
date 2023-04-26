%%%%%%%%%
% SETUP %
%%%%%%%%%

\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{presentation}
\LoadClass{beamer}
\RequirePackage{ali-macros}

%%%%%%%%%%
% COLORS %
%%%%%%%%%%

% DEFAULTS
\def\logoPath{logos/carleton_logo.png}
\def\colorOne{carleton-blue}
\def\colorTwo{carleton-blue}
\def\colorThree{carleton-maize}
\def\logoPath{logos/carleton_logo.png}
\def\logoWidth{.2}

% UMN COLORS
\xdefinecolor{umn-maroon}{HTML}{7A0019}
\xdefinecolor{umn-maroon-dark}{HTML}{5B0013}
\xdefinecolor{umn-gold}{HTML}{FFCC33}
\xdefinecolor{umn-gold-dark}{HTML}{FFB71E}
\xdefinecolor{umn-gold-light}{HTML}{FFDE7A}

\DeclareOption{umn}{
	\def\colorOne{umn-maroon}
	\def\colorTwo{umn-maroon-dark}
	\def\colorThree{umn-gold-light}
	\def\logoPath{logos/umn_logo.png}
	\def\logoWidth{.2}
}

% CARLETON COLORS
\xdefinecolor{carleton-blue}{HTML}{003E7E}
\xdefinecolor{carleton-blue-light}{HTML}{2D538F}
\xdefinecolor{carleton-maize}{HTML}{FFD24F}
\xdefinecolor{carleton-maize-dark}{HTML}{EEB111}
\xdefinecolor{carleton-maize-light}{HTML}{FFEFC8}

\DeclareOption{carleton}{
	\def\colorOne{carleton-blue}
	\def\colorTwo{carleton-blue}
	\def\colorThree{carleton-maize}
	\def\logoPath{logos/carleton_logo.png}
	\def\logoWidth{.25}
}

%%%%%%%%%%
% BEAMER %
%%%%%%%%%%

% pass all other class options to beamer
\DeclareOption*{\PassOptionsToClass{\CurrentOption}{article}}
\ProcessOptions\relax

% TITLES
\setbeamerfont{title}{series=\bfseries}
\setbeamercolor{title}{fg=\colorOne}
\setbeamercolor{subtitle}{fg=\colorOne!90}

\setbeamerfont{date}{size=\small}

\setbeamerfont{frametitle}{}
\setbeamercolor{frametitle}{fg=\colorOne}

% LISTS
\setbeamerfont*{enumerate item}{series=\bfseries}
\setbeamercolor{item}{fg=\colorOne}

% FRAME COLORS
\setbeamercolor{lower separation line head}{bg=\colorOne}
\setbeamercolor{palette tertiary}{fg=\colorTwo,bg=\colorThree}
\setbeamercolor{palette quaternary}{fg=\colorTwo,bg=\colorThree}

\usefonttheme[onlymath]{serif}
\setbeamertemplate{headline}[none]
\setbeamertemplate{navigation symbols}{}

% \setbeamercovered{transparent}
\useoutertheme{infolines}
\useoutertheme[subsection=false]{miniframes}

% HEADER
\addtobeamertemplate{headline}{}{\vspace{1em}}

% FOOTER 
\setbeamertemplate{footline}{\parbox{\textwidth}{
		\hspace{1em}
		\vspace{1em}
		\includegraphics[width=\logoWidth\paperwidth]{\logoPath}
		\hfill
		\color{gray}\tiny
		\insertframenumber\,/\,\inserttotalframenumber
		\hspace{1em}
	}}

% SPACING
\setbeamersize{
	text margin right=3em,
	text margin left=3em,
}
