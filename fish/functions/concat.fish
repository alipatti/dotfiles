function concat
    for f in $argv
        echo "$f:"
        echo '```'
        cat $f
        echo '```'
        echo
    end
end
