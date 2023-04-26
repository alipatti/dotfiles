# https://www.mankier.com/1/latexmk

$pdf_mode = 4; # compile directly to pdf w/ lualatex

$lualatex = "lualatex -file-line-error -interaction=nonstopmode --shell-escape %O %S";
# "python3 /Applications/SageMath-9-6.app/Contents/Frameworks/Sage.framework/Versions/9.6/local/var/lib/sage/venv-python3.10.3/share/texmf/tex/latex/sagetex/run-sagetex-if-necessary.py %B";

$clean_ext = 'fls log synctex.gz sagetex.*';

@default_files = ();

# enable compilation of rnw files
# from: https://xuc.me/blog/latex-and-r/
if(grep(/\.(rnw|rtex)$/i, @ARGV)) {
    $latex = 'internal rnw2tex ' . $latex;
    $pdflatex = 'internal rnw2tex ' . $pdflatex;
    $lualatex = 'internal rnw2tex ' . $lualatex;

    my $knitr_compiled = {};
    sub rnw2tex {
        for (@_) {
            next unless -e $_;
            my $input = $_;
            next unless $_ =~ s/\.(rnw|rtex)$/.tex/i;
            my $tex = $_;
            my $checksum = (fdb_get($input))[-1];
            if (!$knitr_compiled{$input} || $knitr_compiled{$input} ne $checksum) {
                my $ret = system("Rscript -e \"knitr::knit('$input')\"");
                if($ret) { return $ret; }
                rdb_ensure_file($rule, $tex);
                $knitr_compiled{$input} = $checksum;
            }
        }
        return system(@_);
    }

    # patch synctex on complete
    $success_cmd = "Rscript -e \"patchSynctex::patchSynctex('test.rnw', verbose =T)\"";

    # clean up generated .tex file when running `latexmk -c <root_file>`
    $clean_ext .= ' %R.tex %R-concordance.tex knitr.sty';
}
