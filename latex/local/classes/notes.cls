\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{notes}

\LoadClass{article}

\RequirePackage{macros}
\RequirePackage{styles}

\RequirePackage[hidelinks]{hyperref}


% TITLE FORMATTING
\makeatletter
\renewcommand{\maketitle}{
    \begin{center}
        {\LARGE \scshape \@title}

        \vspace{-.5em}
        \rule{.4 \textwidth}{0.5pt}
        
        {\@author \hspace{.4em} $|$ \hspace{.4em} \@date}
    \end{center}

}
\makeatother

% SECTION FORMATTING
\RequirePackage{titlesec}

\titleformat{\section}
    {\Large\bfseries}
    {\thesection}
    {.7em}
    {}
    [\vspace{.25em}\titlerule]

% \titleformat{\section}[block]
%     {\normalfont}
%     {\thesection}{.5em}{\titlerule\\[.8ex]\bfseries\large}

% \titlespacing{\section}{-.5in}{2pc}{1pc}
