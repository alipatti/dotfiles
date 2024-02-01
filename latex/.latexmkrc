# https://www.mankier.com/1/latexmk#List_of_Configuration_Variables_Usable_in_Initialization_Files

$pdf_mode = 4; # compile directly to pdf w/ lualatex
$silent = 1; # don't show log messages
$rc_report = 0; # don't show list of read RC files

$lualatex = "lualatex --interaction=nonstopmode --synctex=1 --shell-escape %O %S";

$clean_ext = 'fls log synctex.gz sagetex.* run.xml';

@default_files = ("main.tex"); # compile main tex file if no arguments given

