$pdf_mode = 1; # compile directly to pdf

# # commands that run at various points in the compilation process
$compiling_cmd = "";
$failure_cmd = "";
$warning_cmd = "";
# $success_cmd = "rm *.{aux,fls,fdb_latexmk,log}";

$pdf_previewer = "open -a 'VS Code'";
$pdflatex = "pdflatex -synctex=1 -file-line-error -interaction=nonstopmode --shell-escape %O %S";

$clean_ext = "log synctex.gz";
