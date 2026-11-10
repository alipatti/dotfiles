function tree --wraps='eza --tree' --description 'eza tree, depth limited to fit the terminal'
    set -l cmd eza --tree --git-ignore --group-directories-first --icons=auto $argv
    set -l depth 3

    # drop a level until the output fits, but always show at least depth 1
    while test $depth -gt 1
        test ($cmd --level=$depth | count) -le (math $LINES - 5); and break
        set depth (math $depth - 1)
    end

    $cmd --level=$depth
end
