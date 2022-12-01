$pdf_mode = 1  # compile directly to pdf

# commands that run at various points in the compilation process
# TODO add log messages
$compiling_cmd = ""
$failure_cmd = ""
$warning_cmd = ""
$success_cmd = ""

# turn on shell-escape flag
$pdflatex = "pdflatex --shell-escape %O %S";
