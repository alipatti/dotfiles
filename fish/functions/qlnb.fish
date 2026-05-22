function qlnb
    set tmp (mktemp -d /tmp/nb_XXXXXX)/out.html
    jupytext --to notebook --output - $argv[1] |
        jupyter nbconvert --to html --stdin --stdout --execute >$tmp
    ql $tmp
end
