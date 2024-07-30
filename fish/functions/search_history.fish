function search_history
    set result (history | fzf --no-sort)

    if test $result
        commandline --function repaint
        commandline --append -- $result
        commandline --function end-of-line
    else
        commandline --function repaint
    end
end
